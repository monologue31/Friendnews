require 'socket'
require 'dbm'
require 'rubygems'
require 'uuidtools'
require "fileutils"
require 'openssl'
require 'base64'

module FriendNews

  class FNS_Server
    def initialize(nntp = nil)
			@nntp = nntp
    end

    def start
      puts "fnsserver:Friend News System Server Started"

			if @nntp
				puts "nntp"
				Thread.start do
					nntp_socket =	TCPServer.open(119)
					loop do
        		conn_nntp = nntp_socket.accept
						cdomain = Socket.getnameinfo(Socket.sockaddr_in(11119,conn_nntp.peeraddr[3]))[0]
        		puts "fnsserver:Connection from #{cdomain} IP:#{conn_nntp.peeraddr[3]} MODE:NNTP"
        		puts "fnsserver:Accepted connection from #{cdomain} MODE:NNTP"
          	conn_nntp.puts(200)
          	process = Process.new(conn_nntp)
          	process.run
          	puts "fnsserver:#{cdomain} done MODE:NNTP"
					end
				end
			end

      fns_socket = TCPServer.open(11119)
      loop do
        conn = fns_socket.accept
				cdomain = Socket.getnameinfo(Socket.sockaddr_in(11119,conn.peeraddr[3]))[0]
        puts "fnsserver:Connection from #{cdomain} IP:#{conn.peeraddr[3]}"
        puts "fnsserver:Accepted connection from #{cdomain}"
        Thread.start do
          conn.puts(200)
          process = Process.new(conn)
          process.run
          puts "fnsserver:#{cdomain} done"
        end
      end
    end
  end

  class Process
	  def initialize(socket = nil)
		  @socket = socket
			@parsemsg = FriendNews::ParseMsg.new
	  end

    def run
      begin
        #initialize
        @tag = nil
        @premission = nil
				loop do
        	if @socket.eof?
        		puts "fnsserver:Connection closed by #{Socket.getnameinfo(Socket.sockaddr_in(119,@socket.peeraddr[3]))[0]}"
        	  @socket.close
						break
        	end
        	while line = @socket.gets
        	  puts "fnsserver:Received request [#{line.chomp}]"
        	  cmd,param = line.split(/\s+/,2) #get command and parameter
        	  param = param.chomp if param
        	  case cmd
        	  when /(?i)post/
              #user check
              if @socket.peeraddr[3] != "127.0.0.1"
                self.response("440 Posting not allowed")
              else
                self.post
              end
        	  when /(?i)ihave/
        	  when "MODE"
        	    if param.chomp == "READER"
        	    	@mode = "reader"
        	      self.response("200 News server ready - posting ok")
        	    elsif param.chomp == "BROWSER"
        	      @mode = "browser"
        	    else
        	      self.response("201 News server ready - posting not allowed")
        	    end
        	  when /(?i)list/
              self.list
        	  when /(?i)group/
              self.group(param)
        	  when /(?i)xover/
              unless @tag
                self.response("412 No newsgroup has been selected")
                next
              end
              self.xover(param)
        	  when /(?i)article/
              unless tag
                self.response("412 No newsgroup has been selected")
                next
              end
              unless param
                self.response("420 No current article has been selected")
                next
              end
              self.article(param)
        	  when /(?i)quit/
        	    puts "fnsserver:Connection closed by #{@socket.addr[2]}"
        	    @socket.close
        	    return
        	  else
        	    self.response("500 Command not recognized")
        		end
       		end
        end
			rescue => e
				puts "fnsserver error"
		    puts e.to_s
        @socket.close
      end
		end
    
    def post
      	#get message
      	self.response("340 Sent article to be posted.end with <.>")
      	msg_str = ""
      	while line = @socket.gets
      	  break if line == ".\r\n"
      	  msg_str += line
      	end
      	msg = @parsemsg.to_hash(msg_str)

			  #convert newsgroups to tag
			  if msg.has_key?("Newsgroups")
			  	msg["Tags"] = msg["Newsgroups"]
			  	msg.delete("Newsgroups")
			  end
=begin 
        p "Check Msg Type"
			  #check control header
        if msg.has_key?("Control")
          return "441 Posting failed - Can't parse control message" unless self.parse_cmsg(msg)
          msg["Tags"] = "control"
        end
=end
        p "Sign Msg"
			  #check signature
        msg["Signature"] = $fns_conf["signature"] #Which header should be signed

        p "Parse Tag"
        active = DBM::open("#{$fns_path}/db/active",0666)
        tags = Array.new
        msg["Tags"].split(",").each do |t|
          tags << t if active.has_key?(t)
        end
        tags << "junk" if tags.empty?

        p "Create Msg_id"
			  #message-id
        while 1
          msg["Message-ID"] = "<#{UUIDTools::UUID.random_create().to_s}@#{msg["From"].split("\s")[0]}>"
          break unless chk_hist?(msg["Message-ID"])
        end

        p "Path,Expires,Date,Msg-Sign"
        msg["Path"] = $fns_conf["host"]
        msg["Expires"] = $fns_conf["expires"]
        msg["Date"] = Time.now.to_s unless msg.key?("Date")
        msg["Signature"] = $fns_conf["signature"]
        p msg
        msg["Msg-Sign"] = self.digital_sign(msg,"localhost","sign") #Sign the message
        active = DBM::open("#{$fns_path}/db/active",0666)
        
        p "artnum"
        #create artnum
        main_artnum = (active["all"].split(",")[1].to_i + 1).to_s
        self.add_artnum("all",main_artnum) 
        tags.each do |t|
          artnum = (active[t].split(",")[1].to_i + 1).to_s
          self.update_active(t,artnum)
          self.update_main_sub(tag,artnum,main_artnum)
        end

        p "Save file"
        File.open(path,"w") do |f|
          f.write @parsemsg.to_str(msg)
        end
        self.(msg,main_artnum)
        puts "fnsserver:Article <#{msg["Message-ID"]}> posted ok"
        #Feed message  
        $fns_queue.push("#{main_artnum},#{msg["Newsgroups"]}")
        return "240 Article posted ok"
    end

    def ihave(param)
      unless self.chk_hist?(param)
        self.parse_ihave(param)
      else
        self.response("437 Article rejected - do not try again")
      end
      self.response("335 Send article to be transferred.end with <.>")
      msg_str = ""
      while line = @socket.gets
        break if line == ".\r\n"
        msg_str += line
      end
      msg = @parsemsg.to_hash(msg_str)
      #Verify Sign
      unless self.digital_sign(msg,"public","verify")
        msg["Body"] = "Bad Sign\r\n\r\n#{msg["Body"]}"
        msg["Msg-Sign"] = "Bad Sign"
      end
      if msg.has_key?("Control") && msg["Msg-Sign"] != "Bad Sign"
        unless self.parse_cmsg(msg)
          self.response("437 Article rejected - do not try again")
        end
      end
			#tag mapping
      tags = self.tap_mapping(msg["Newsgroups"])
			tags = self.header_mapping(msg,tags)
      active = DBM::open("#{$fns_path}/db/active",0666)
      tags.each do |t|
        unless active.has_key?(t)
          tags.delete(t)
        end
      end
			
			#add path
      msg["Path"] = "#{@socket.addr[2]}!#{msg["Path"]}"
      #msg["Xref"] = @socket.addr[2]
      #tags.each do |t|
      #  msg["Xref"] += "\s" + t + ":" + self.calc_artnum(t)
      #end
      if msg["Tags"] == "control"
        main_artnum = self.calc_artnum("control")
        path =  "#{$fns_path}/article/control/#{main_artnum}"
      else
        main_artnum = self.calc_artnum("all")
        path =  "#{$fns_path}/article/#{main_artnum}"
      end
      File.open(path,"w") do |f|
        f.write @parsemsg.to_str(msg)
      end
      self.append_hist(msg,main_artnum)
      self.create_artnum(tags,main_artnum)
      puts "fnsserver:Article <#{msg["Message-ID"]}> transferred ok"
      self.response("235 Article transferred OK")
      #feed message
      $fns_queue.push("#{main_artnum},#{msg["Newsgroups"]}")
      return
    end

    def list
      self.response("215 List of newsgroups follows")
      active = DBM.open("#{$fns_path}/db/active",0666)
      active.each_key{|t|
        min_artnum,max_artnum,p = active[t].split(",")
        res = t + "\s" + min_artnum + "\s" + max_artnum + "\s" + p
        self.response(res)
      }
      self.response(".")
      active.close
    end

    def group(param)
      active = DBM.open("#{$fns_path}/db/active",0666)
      min_artnum,max_artnum,p,num = active[param.chomp].split(",")
      active.close
      res = "211 #{num}\s#{min_artnum}\s#{max_artnum}\s#{param}\sgroup selected"
      tag = param.chomp
      self.response(res)
    end

    def xover(tag,param)
      min,max = param.split("-")
      min = min.to_i
      if max
        max = max.to_i
      else
        max = (active[tag].split(",")[1].to_i).to_s
      end
      self.response("224 #{param} fields follow")
      history = DBM::open("#{$fns_path}/db/history",0666)
      sub_artnum = DBM.open("#{$fns_path}/db/tags/#{@tag}",0666) 
      while min <= max
      	p min
      	p max
        atrnum = sub_artnum[min.to_s]
        next unless File.exist?("#{$fns_path}/article/#{artnum}")
        artnum_msgid = DBM::open("#{$fns_path}/db/artnum_msgid",0666)
        msg_id = artnum_msgid[artnum]
        artnum_msgid.close
      	p msg_id
        #files->[article number][subject][from][date][message size][lines][xref][newsgroups]
        fields = history[msg_id].split("!")
        res = "#{min.to_s}\t#{fields[1]}\t#{fields[2]}\t#{fields[3]}\t#{msg_id}\t#{fields[4]}\t#{fields[5]}\t#{fields[6]}"
        self.response(res)
        min += 1
      end
      self.response(".\r\n")
    end

    def article(tag,param)
      sub_artnum = DBM.open("#{$fns_path}/db/tags/#{tag}",0666)
      path = "#{$fns_path}/article/#{sub_artnum[param]}"
      sub_artnum.close
      unless File.exist?(path)
        self.response("423 No such article number in this group")
      end
      msg_id = DBM::open("#{$fns_path}/db/artnum_msgid",0666)
      self.response("220 #{param} #{msg_id[param]}")
      msg_id.close
      msg = File.read(path)
      if @mode == "reader"
      	tmp = @parsemsg.to_hash(msg)
        tmp["Tags"] = tmp["Newsgroups"]
        tmp.delete("Nesgroups")
        msg = @parsemsg.to_str(tmp)
      end
      line = msg.split("\r\n")
      line.each do |l|
       	#self.response(line)
        @socket.puts(l + "\r\n")
      end
      self.response(".\r\n")
    end

    #Response
    def response(res)
      puts "fnsserver:Sent response [#{res}]"
      @socket.puts(res)
    end

    def update_active(tag,artnum)
      active = DBM::open("#{$fns_path}/db/active",0666)
      min_artnum,max_artnum,p,num = active[tag].split(",")
      min_artnum = "1" if artnum == "1"
      max_artnum = artnum if artnum.to_i > max_artnum.to_i
      active[tag] = min_artnum + "," + max_artnum + "," +  p + "," + num
      active.close
    end
    
    def update_main_sub(tag,main_artnum,sub_artnum)
      sub_main = DBM::open("#{$fns_path}/db/tags/#{tag}",0666)
      sub_main[sub_artnum] = main_artnum
      sum_main.close
      main = DBM::open("#{$fns_path}/db/tags/all",0666)
      if main[main_artnum]
        main[main_artnum] += "!#{tag}:#{sub_artnum}"
      else
        main[main_artnum] = "#{tag}#{sub_artnum}"
      end
    end

    def rm_artnum(tag,main_artnum)
      return nil if tag == "all"
      #remove sub_artnum
      sub_main = DBM::open("#{$fns_path}/db/tags/#{tag}",0666)
      sub_artnum = sub_main.index(main_artnum) 
      sub_main.delete(sub_artnum)
      sub_main.close
=begin
      active = DBM::open("#{$fns_path}/db/active",0666)
      min_artnum,max_artnum,p,num = active[tag].split(",")
      num = (num.to_i - 1).to_s
      if sub_artnum == max_artnum
        max_artnum = (max_artnum.to_i - 1).to_s 
      else if sub_artnum = min_artnum
        
      end
      active[tag] = min_artnum + "," + max_artnum + "," +  p + "," + num
      active.close
=end
      #remove main_artnum
      main = DBM::open("#{$fns_path}/db/tags/all",0666)
      tag_sub_artnum = main[main_artnum].split("!")
      tag_sub_artnum.each do |t|
        tag,sub_artnum = t.split(":")
        tmp += ""
      end
      main.delete(main_artnum)
      main.close
    end

    def append_hist(msg,art_num)
      history = DBM::open("#{$fns_path}/db/history",0666)
      history[msg["Message-ID"]] = "#{art_num}!#{msg["Subject"]}!#{msg["From"]}!#{msg["Date"]}!#{File.size("#{$fns_path}/article/#{art_num}")}!#{msg["Lines"]}!#{msg["Xref"]}!#{msg["Newsgroups"]}"
      history.close
      artnum_id = DBM::open("#{$fns_path}/db/artnum_id",0666)
      artnum_id[art_num] = msg["Message-ID"]
      artnum_id.close
    end

    def chk_hist?(msg_id)
			history = DBM::open("#{$fns_path}/db/history",0666)
			if history.has_key?(msg_id)
				history.close
				return true
			else
				history.close
				return nil
			end
    end

    #Control message parese
    def parse_cmsg(msg)
      self.chk_premession()
      cmd,param = msg["Control"].split("\s",2)
      case cmd
      when "cancel"
        return self.cancel_msg(param,msg)
      when "newtag"
        return self.new_tag(param,msg)
      when "rmtag"
        return self.rm_tag(param,msg)
      when "newml"
        return self.new_ml(param,msg)
			when "updateml"
        return self.update_ml(param,msg)
			when "addarttag"
        return self.add_art_tag
			when "rmarttag"
        return self.rm_art_tag
			when "sendme"
        return self.sendmme
			when "sendkey"
				
      else
        return nil
      end
    end
    
    def cancel_msg(msg_id,msg)
      if self.chk_hist?(msg_id)
        history = DBM::open("#{$fns_path}/db/history",0666)
        return "3xx" if history[msg_id] == "Canceled"
        artnum_id = DBM::open("#{$fns_path}/db/artnum_id",0666)
        main_artnum = artnum_id.index(msg_id)
        if File.exist?("#{$fns_path}/article/#{main_artnum}")
          delmsg = @parsemsg.to_hash(File.read("#{$fns_path}/article/#{art_num}"))
          if msg["From"] == delmsg["From"]
            File.delete("#{$fns_path}/article/#{art_num}")
          else
            #wrong auther
            return "Wrong auther"
          end
          #change history file
          history[msg_id] = "Canceled"
          #change tag file
          return "2xx"
        end
      else
        return "3xx"
      end
    end

    def new_tag(tag,msg)
      active = DBM::open("#{$fns_path}/db/active",0666)
      return "3xx" if active.has_key?(tag)
      history = DBM::open("#{$fns_path}/db/history",0666)
      sub_artnum = DBM::open("#{$fns_path}/db/tags/#{param}",0666)
      cnt = 0 #article number
      history.each_key do |k|
        tags = history[k].split("!")[7].split(",")
        main_artnum = history[k].split("!")[0]
        tags.each do |t|
          if t == tag
            cnt += 1
            sub_artnum[cnt.to_s] = main_artnum
            self.rm_artnum("junk",main_artnum)
          end
        end
      end
      if cnt == 0
        active[param] = "1,0,y,0"
      else
        active[param] = "1,#{cnt.to_s},y,#{cnt.to_s}"
      end
      active.close
      return "2xx"
    end

    def rm_tag(tag,msg)
      active = DBM::open("#{$fns_path}/db/active",0666)
      return nil unless active.has_key?(tag)
      sub_artnum = DBM::open("#{$fns_path}/db/tags/#{param}",0666)
      sub_artnum.each_key do |k|
#        self.update_active("junk",k)
      end
      active.delete(tag)
      active.close
      return true
    end

    def new_ml(name,msg)
      ml = DBM::opn("#{$fns_path}/etc/memberlist/#{name}",0666) 
      return nil if ml["Version"] <= Time.now.to_s
			msg["From"] = "#{host_name}\s<#{host_name}@#{host_domain}>"
      ml["Version"] = Time.now.to_s
      msg["Body"].split("\r\n").each do |m|
        host,permission = m.split(/\s*|\t*/)
        ml[host] = permission
      end
    end

    def update_ml(name,msg)
      ml = DBM::opn("#{$fns_path}/etc/memberlist/#{name}",0666) 
			premission_from = ml[(msg["From"].split("\s")[1]).splite("@")[1]]
			return if (permission_from != "admin") && !(permission_from.inclued("w"))
    end

    def add_art_tag(param,msg)
			artnum,tag = param.split("\s")
			msg = @parsemsg.to_hash(File::read("#{$fns_path}/article/#{artnum}"))
			msg["Tags"] += ",#{tag}"
    	File.open("#{$fns_path}/article/#{artnum}","w") do |f|
      	f.write @parsemsg.to_str(msg)
    	end
    end

    def rm_art_tag(param,msg)
			artnum,tag = param.split("\s")
			art = File::open("#{$fns_path}/article/#{artnum}")
			msg = @parsemsg.to_str(art.read)
			tags = msg["Tags"].split(",")
			if tags.inclued(tag)
				tags.delete(tag)
			end
			tags.each do |t|
				msg["Tags"] += "#{t},"
			end
			msg["Tags"] = msg["Tags"].chop
    	File.open("#{$fns_path}/article/#{artnum}","w") do |f|
      	f.write @parsemsg.to_str(msg)
    	end
    end

    def sendme(param)
			host_domain,count = param.split("\s")
			hosts = DBM::open("#{$fns_path}/db/hosts",0666)
			key_pool = DBM.open("#{$fns_path}/db/key_pool")
			count = (count.to_i + 1).to_s
			msg["Control"] = "sendme\s#{host_domain}\s#{count}"
			unless hosts.has_value?(host_domain)
				return nil if count.to_i < 0
				return msg
			end
			host = hosts.index(host_domian)
			return msg unless key_pool.has_key?(host) 
    end

    def chk_premission()
    end

    #Digital sign
	  def digital_sign(msg,host_name,action)
		  begin
		    tmpfile = File.open("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}","w+")
		    sign_headers = msg["Signature"].split(",")
		    i = 0
		    while i < sign_headers.length
			    tmpfile.puts(sign_headers[i] + ":\s" + msg[sign_headers[i]])
			    i += 1
		    end
		    tmpfile.puts(msg["Body"])
        tmpfile.close
				key_pool = DBM.open("#{$fns_path}/db/key_pool")
				key_pool[host_name]
			  key = OpenSSL::PKey::RSA.new(key_pool[host_name])	
				key_pool.close
	 	    digest = OpenSSL::Digest::SHA1.new()
			  case action
			  when "sign"
          puts "fnsserver:Starting sign message #{msg["Message-ID"]} with private key"
				  msg_sign = Base64.encode64(key.sign(digest,File.read("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}"))).delete("\n")
          #del tmp file
          File.delete("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}")
          puts "fnsserver:Sign message#{msg["Message-ID"]} with private key ok"
				  return msg_sign
			  when "verify"
          print "fnsserver:Starting verify message#{msg["Message-ID"]}..."
				  if key.verify(digest,Base64.decode64(msg["Msg-Sign"]),File.read("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}"))
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}")
            puts "fnsserver:Verify message#{msg["Message-ID"]} with public key ok"
					  return true
				  else
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{msg["Nessage-ID"]}.#{action}")
					  puts "fnsserver:Bad sign"
					  return nil
				  end
			  else
          return nil
			  end
		  rescue => e
			  puts e.to_s
			  return nil
		  end
	  end

	  def tag_mapping(tags)
      tag = tags.split(",")
      ctags = Arrary.new
      tag_rule = DBM::open("#{$fns_path}/etc/tag_rule",0666)
      tag.each do |t|
        tag_rule.each_key do |k|
          if /#{k}/ =~ t
          	ctag << tag_rule[k]
					else
						ctag << t
        	end
        end
      end
      return ctag
    end
	
		def header_mapping(tag,msg)
			host_rule = DBM::open("#{$fns_path}/etc/host_rule",0666)
			header_rule = DBM::open("#{$fns_path}/etc/header_rule",0666)
			host_domain = (msg["From"].split("@")[1]).split(">")[0]
      host = DBM::open("#{$fns_path}/db/hosts",0666)
			host_name = host.index(host_domain)
			if host_rule.has_key?(host_name)
				rules = host_rule[host_name]
				rule = rules.split("!")
				rule.each do |r|
					header,value,ttag = rule.split(",")
					tag << ttag if /#{value}/ =~ msg[header] 
				end
			else
				header_rule.each do |r|
					if msg.has_key?(r)
						ttag = "#{r}.#{msg[r]}"
						tag << ttag
					end
				end
			end	
			return tag
		end
  end

  class FNS_Feeds
    def initialize()
      @fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0666)
      @feedlist = Queue.new
			@parsemsg = FriendNews::ParseMsg.new
  	end

	  def run
      begin
        self.load_feedlist
        #thread load feedlist
	  	  Thread.start do
	  	  	loop do
            sleep($feed_time)
            self.load_feedlist
  		  	end
  		  end

        #thread for fnsserver 
        Thread.start do
          loop do
            artnum,tags = $fns_queue.pop().split(",")
            self.feed_msg(artnum,tags)
          end
        end

        #thread feed message
        Thread.start do
          loop do
            host_id,msg_id = @feedlist.pop.split(",")
						puts "nntpfeeds:feed message #{msg_id} to #{host_id}"
            self.feed_msg(host_id,msg_id.split(","))
          end
        end
      rescue => e
        puts "nntpfeeds error"
        puts e
      end
    end
    
    def feed_msg(artnum,tags)
      msg = @parsemsg.to_hash(File.read("#{$fns_path}/article/#{artnum}"))
			puts "nntpfeeds:recevie messgae #{msg["Message-ID"]}"
			list = Array.new
			list.clear	
      if msg.has_key?("Distribution")
        msg["Distribuliton"].split(",").each do |d|
          DBM::opn("#{$fns_path}/etc/memberlist/#{d}",0666).each_key do |h|
            unless list.include(h)
              list << h
            end
          end
        end
      else
        @fnsfeed.each_key do |h|
          list << h
        end
      end
      tag = tags.split(",")
      list.each do |l|
        hosts = @fnsfeed[l].split(",")
        tag.each do |t|
          if !hosts.include?("!#{t}") || (hosts.include?("!*") && !hosts.include?("t"))
            self.append_feedhist(msg["Message-ID"],l,nil)
            @feedlist.push("#{l},#{msg["Message-ID"]}")
          end
        end
      end
    end

    def append_feedhist(msg_id,host,stat_code)
      feedhist = DBM::open("#{$fns_path}/db/feedhist/#{host}")
      feedhist[host] = stat_code
      feedhist.close
    end

    def del_feedhist(msg_id,host)
      feedhist = DBM::open("#{$fns_path}/db/feedhist/#{host}")
      feedhist.delete(msg_id)
      feedhist.close
    end

    def load_feedlist
      @fnsfeed.each_key do |k|
        feedhist = DBM::open("#{$fns_path}/db/feedhist/#{k}")
        msg_id = ""
				cnt = 0
        feedhist.each_key do |m|
        	if (feedhist[m] == "436" || feedhist[m] == nil)
						msg_id += "#{m},"
						cnt += 1
					end
        end
        msg_id = msg_id.chop
        @feedlist.push("#{k},#{msg_id}") if cnt > 0
        feedhist.close
			end
    end

    def feed_msg(host_id,msg_id)
      client = FriendNews::FNS_Client.new(11119)
      host_ip = DBM::open("#{$fns_path}/db/hosts",0066)
      if client.connect(host_ip[host_id])
      	msg_id.each do |m|
      	  stat_code = client.command("ihave",m)
					puts "nntpfeeds:feed message #{m} status code #{stat_code}"
      	  self.append_feedhist(m,host,stat_code)
      	end
      	client.disconnect
			else
				puts "nntpfeeds:can't connet to host #{host_id}"
      	msg_id.each do |m|
      	  self.append_feedhist(m,host,"436")
      	end
			end
    end
    
  end

  class FNS_Client
    def initialize(port)
      @port = port
			@parsemsg = FriendNews::ParseMsg.new
    end

    def connect(host)
      begin
        @socket = TCPSocket.open(host,@port)
        puts "nntpclient:Connecting #{host} with port[#{@port}] successful code #{@socket.gets}"
				return true
      rescue => e
        puts "nntpclient:Connecting #{host} with port[#{@port}] error [#{e}]"
				return nil
      end
    end

    def disconnect
      @socket.close
    end

    def command(cmd,param)
      case cmd
      when /(?i)ihave/
        stat_code = self.ihave(param)
      end

      #return code
      return stat_code
    end

    def request(cmd_line)
      @socket.puts(cmd_line)
      puts "nntpclient:Send command <#{cmd_line}>"
      while code = @socket.gets
        next unless code
        puts "nntpclient:Receive status code <#{code.chomp}>"
        return code
      end
    end

    def send_msg(str)
			line = str.split("\r\n")
      line.each do |l|
        @socket.puts(l + "\r\n")
      end
      @socket.puts(".\r\n")
      while code = @socket.gets
        next unless code
        return code
      end
    end

    def text_res
      res = ""
      while line = @socket.gets
        break if line == ".\r\n"
        res += line
      end
      return res
    end

    def ihave(msg_id)
      stat_code = self.request("IHAVE #{msg_id}")
      return stat_code unless /335/ =~ stat_code
      history = DBM::open("#{$fns_path}/db/history",0666)
      tag = history[msg_id].split("!")[7]
      artnum = history[msg_id].split("!")[0]
      if tag == "control"
        path = "#{$fns_path}/article/control/#{artnum}"
      else
        path = "#{$fns_path}/article/#{artnum}"
      end
      stat_code = send_msg(File.read(path))
      return stat_code
    end

		def post(msg)
      stat_code = self.request("POST")
			return stat_code unless /340/ =~ stat_code
			stat_code = send_msg(@parsemsg.to_str(msg))
		end
  end

	class ParseMsg
		def initialize 
			@headers = Hash.new	
      @headers["1"] = "Date"
      @headers["2"] = "From"
      @headers["3"] = "Message-ID"
      @headers["4"] = "Subject"
      @headers["5"] = "Tag"
      @headers["6"] = "Path"
      @headers["7"] = "Expires"
      @headers["8"] = "Organization"
      @headers["9"] = "Reply-To"
      @headers["10"] = "Lines"
      @headers["11"] = "Signature"
      @headers["12"] = "Followup-To"
      @headers["13"] = "References"
      @headers["14"] = "Keywords"
      @headers["15"] = "Summary"
      @headers["16"] = "Distribution"
      @headers["17"] = "User-Agent"
      @headers["18"] = "MIME-Version"
      @headers["19"] = "Content-Type"
      @headers["20"] = "Content-Transfer-Encoding"
      @headers["21"] = "Control"
      @headers["22"] = "Xref"
      @headers["23"] = "Msg-Sign"
      @headers["24"] = "Body"
		end

  	def to_str(msg_hash)
	  	msg = ""
  		i = 1
  		while i <= @headers.length
  			unless @headers[i.to_s] == "Body"
  				if msg_hash[@headers[i.to_s]]
  					msg += @headers[i.to_s] + ":\s" + msg_hash[@headers[i.to_s]] + "\r\n"
  				end
  			else
          msg += "\r\n"
  				msg += msg_hash[@headers[i.to_s]]
  			end
  			i += 1
  		end	
  		return msg
  	end

    #Covert string to hash table
  	def to_hash(str)
      i = 0
      msg = Hash.new
      msg["Body"] = ""
      line = str.split("\r\n")
      while i < line.length
				unless line[i] == ""
          header_field,field_value = line[i].split(/\s*:\s*/,2)
					msg[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end
      msg_line = 0
      while i < line.length
		   	msg["Body"] += "#{line[i]}\r\n"
        break if line[i] == "."
		  	msg_line += 1
        i += 1 
      end
      msg["Lines"] = msg_line.to_s
	  	return msg
  	end
	end

	class FNS_Managment
		def initialize()
		end

    def add_host(host_name,host_domain)
      host = DBM::open("#{$fns_path}/db/hosts",0666)
      host[host_name] = host_domain
      p "create host <#{host_name}> ok,social router domain <#{host_domain}>"
			host.close
    end

		def rm_host(host_name)
      host = DBM::open("#{$fns_path}/db/hosts",0666)
			host.delete(host_name)
			host.close
		end

    def show_host
      host = DBM::open("#{$fns_path}/db/hosts",0666)
      host.each do |h|
        p h
      end
    end

    def add_feedrule(host_name,rule)
      host = DBM::open("#{$fns_path}/db/hosts",0666)
      if host.has_key?(host_name)
        fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0066)
        fnsfeed[host_name] = rule
        msg = "host <#{host_name}> add feedrule ok"
      else
        msg "do not find host <#{host_name}>"
      end
			return msg
		end

		def rm_feedrule(host_name)
    	fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0066)
			fnsfeed.delete(hostname)
		end

    def add_mapping(rule,tag)
      tag_rule = DBM::open("#{$fns_path}/etc/tag_rule",0666)
      tag_rule[rule] = tag
      msg = "rule <#{rule}> to <#{tag}>"
			return msg
    end

		def rm_mapping(rule)
      tag_rule = DBM::open("#{$fns_path}/etc/tag_rule",0666)
			tag_rule.delete(rule)
		end

		def add_filter(header,param,tag)
			filter = DBM::open("#{$fns_path}/etc/filter/#{header}",0666)
		end

		def rm_filter()
		end

		def set_env(param,value)
			conf = DBM.open("#{$fns_path}/etc/fns_conf")
		end

		def add_key(host_name,key)
			key_pool = DBM.open("#{$fns_path}/db/key_pool")
			key_pool[host_name] = key
			key_pool.close
		end

		def rm_key(host_name)
			key_pool = DBM.open("#{$fns_path}/db/key_pool")
			key_pool.delete(host_name)
			key_pool.close
		end

		def sys_init(host)
      FileUtils.mkpath("log")
      FileUtils.mkpath("tmp")
      FileUtils.mkpath("etc")
      FileUtils.mkpath("db/tags")
      FileUtils.mkpath("db/feedhist")
      FileUtils.mkpath("article/control")

      #configure file
      fnsconf = DBM.open("#{$fns_path}/etc/fns_conf",0666)
      fnsconf["fns_path"] = File.expand_path("./")
      fnsconf["host"] = host
      fnsconf["expire"] = "30"
      fnsconf["signature"] = "From,Subject,Tags,Message-ID,Distribution"
      fnsconf.each do |f|
        p f
      end
      #clear message history
      history = DBM::open("#{File.expand_path("./")}/db/history",0666)
      history.clear
      #clear feed histroy

			#clear tag
      fnstag = DBM::open("#{File.expand_path("./")}/db/active",0666)
      fnstag.clear
      fnstag["all"] = "0,0,y,0"
      fnstag["control"] = "0,0,y,0"
      fnstag["junk"] = "0,0,y,0"
      
		end
		
		def post(msg,mode)
			fns_post = FirendNews::Process.new
			return fns_post.parse_post(msg,mode)
		end

		def article(artnum)
			art = File.read("#{$fns_path}/article/#{artnum}")
			return art
		end
    
    def log(type,str)
      
    end
	end

end
