require 'socket'
require 'dbm'
require 'rubygems'
require 'uuidtools'
require "fileutils"
require 'openssl'
require 'base64'

module FriendNews

  class NNTPServer
    def initialize(port)
      @socket = TCPServer.open(port)
    end

    def start
      puts "nntpserver:NNTP Server Started"
      loop do
        conn = @socket.accept
        puts "nntpserver:Connection from #{conn.addr[2]} IP:#{conn.addr[3]}"
        puts "nntpserver:Accepted connection from #{conn.addr[2]}"
        Thread.start do
          conn.puts(200)
          process = NNTPProcess.new(conn)
          process.run
          puts "nntpserver:#{conn.addr[2]} done"
        end
      end
    end
  end

  class NNTPProcess
	  def initialize(socket)
		  @socket = socket
	  end

    def run
      begin
        #initialize
        tag = nil
        premission = nil
        loop do
          if @socket.eof?
            @socket.close
            puts "nntpserver:Connection closed by #{@socket.addr[2]}"
          end
        
          while line = @socket.gets
            puts "nntpserver:Received request [#{line.chomp}]"
            cmd,param = line.split(/\s+/,2) #get command and parameter
            param = param.chomp if param
            case cmd
            when /(?i)post/
              #user check
              if @socket.addr[3] == "127.0.0.1"
                self.parse_post
              else
                self.response("440 Posting not allowed")
              end
            when /(?i)ihave/
              unless self.chk_hist?(param)
                self.parse_ihave(param)
              else
                self.response("437 Article rejected - do not try again")
              end
            when "MODE"
              if param.chomp == "READER"
                self.response("200 News server ready - posting ok")
              else
                self.response("201 News server ready - posting not allowed")
              end
            when /(?i)list/
              self.response("215 List of newsgroups follows")
              active = DBM.open("#{$fns_path}/db/active",0666)
              active.each_key{|t|
                min_artnum,max_artnum,p = active[t].split(",")
                res = t + "\s" + min_artnum + "\s" + max_artnum + "\s" + p
                self.response(res)
              }
              self.response(".")
              active.close
            when /(?i)group/
              active = DBM.open("#{$fns_path}/db/active",0666)
              min_artnum,max_artnum,p,num = active[param].split(",")
              res = "211 #{num}\s#{min_artnum}\s#{max_artnum}\s#{param} group selected"
              tag = param
              self.response(res)
              active.close
            when /(?i)xover/
              unless tag
                self.response("412 No newsgroup has been selected")
                next
              end
              min,max = param.split("-")
              min = min.to_i
              if max
                max = max.to_i
              else
                max = self.calc_artnum(tag).to_i - 1
              end
              self.response("224 #{param} fields follow")
              hist = DBM::open("#{$fns_path}/db/history",0666)
              if tag == "control"
                artnum_msg_id = DBM::open("#{$fns_path}/db/artnum_msg_id_ctl",0666)
              else
                artnum_msg_id = DBM::open("#{$fns_path}/db/artnum_msg_id",0666)
              end
              sub_artnum = DBM.open("#{$fns_path}/db/tags/#{tag}",0666) if tag != "control" && tag != "all"
              while min <= max
                if tag != "control" && tag != "all"
                  atrnum = sub_artnum[min.to_s]
                else
                  artnum = min.to_s
                end
                if tag == "control"
                  path = "#{$fns_path}/article/control/"
                else
                  path = "#{$fns_path}/article/"
                end
                next unless File.exist?("#{path}#{artnum}")
                msg_id = artnum_msg_id[artnum]
                #files->[article number][subject][from][date][message size][lines][xref][newsgroups]
                fields = history[msg_id].split("!")
                res = "#{min.to_s}\t#{fields[1]}\t#{fields[2]}\t#{fields[3]}\t#{msg_id[sub_artnum[f.to_s]]}\t#{fields[4]}\t#{fields[5]}\t#{fields[6]}"
                self.response(res)
                min += 1
              end
              self.response(".")
              sub_artnum.close
              history.close
              msg_id.close
            when /(?i)article/
              unless tag
                self.response("412 No newsgroup has been selected")
                next
              end
              unless param
                self.response("420 No current article has been selected")
              end
              if tag == "control"
                path = "#{$fns_path}/article/control/#{param}"
              else
                sub_artnum = DBM.open("#{$fns_path}/db/tags/#{tag}",0666)
                path = "#{$fns_path}/article/#{sub_artnum[param]}"
                sub_artnum.close
              end
              if File.exist?(path)
                self.response("423 No such article number in this group")
                next
              end
              msg_id = DBM::open("#{$fns_path}/db/msg_id",0666)
              self.response("220 #{param} #{msg_id[param]} article retrieved - head and boy follow")
              msg_id.close
              msg = File.open(path)
              while line = msg.gets
                #self.response(line)
                @socket.puts(line)
              end
              self.response(".")
              msg.close
            when /(?i)quit/
			        puts "nntpserver:Connection closed by #{@socket.addr[2]}"
              @socket.close
              return
            else
              self.response("500 Command not recognized")
            end
          end
        end
		  rescue => e
		    puts e.to_s
        @socket.close
      end
		end

    #Response
    def response(res)
      puts "nntpserver:Sent response [#{res}]"
      @socket.puts(res)
    end

    def parse_post
      self.response("340 Sent article to be posted.end with <.>")
      msg_str = ""
      while line = @socket.gets
        break if line == ".\r\n"
        msg_str += line
      end
      msg = self.to_hash(msg_str)
      if msg.has_key?("Control")
        unless self.parse_cmsg(msg)
          self.response("441 Posting failed - Can't parse control message") 
        end
        msg["Newsgroups"] = "control"
      end
      active = DBM::open("#{$fns_path}/db/active",0666)
      tags = Array.new
      msg["Newsgroups"].split(",").each do |t|
        tags << t if active.has_key?(t)
      end
      p tags
      while 1
        msg["Message-ID"] = "<#{UUIDTools::UUID.random_create().to_s}@#{msg["From"].split("\s")[0]}>"
        break unless chk_hist?(msg["Message-ID"])
      end
      msg["Path"] = @socket.addr[2]
      msg["Signature"] = "From,Subject,Newsgroups,Message-ID" #Which header should be signed
#      msg["Expires"] = $expires
      msg["Date"] = Time.now.to_s unless msg.key?("Date")
      msg["Msg_Sign"] = self.digital_sign(msg,"private","sign") #Sign the message
      msg["Xref"] = @socket.addr[2]
      tags.each do |t|
        msg["Xref"] += "\s" + t + ":" + self.calc_artnum(t)
      end
      if msg["Newsgroups"] == "control"
        main_artnum = self.calc_artnum("control")
        path =  "#{$fns_path}/article/control/#{main_artnum}"
      else
        main_artnum = self.calc_artnum("all")
        path =  "#{$fns_path}/article/#{main_artnum}"
      end
      p msg
      File.open(path,"w") do |f|
        f.write self.to_str(msg)
      end
      self.append_hist(msg,main_artnum)
      self.create_artnum(tags,main_artnum)
      puts "nntpserver:Article <#{msg["Message-ID"]}> posted ok"
      self.response("240 Article posted ok")
      #Feed message  
      $fns_queue.push("#{msg["Message-ID"]},#{msg["Newsgroups"]}")
      return
    end
    
    def parse_ihave(msg_id)
      self.response("335 Send article to be transferred.end with <.>")
      msg_str = ""
      while line = @socket.gets
        break if line == ".\r\n"
        msg_str += line
      end
      msg = self.to_hash(msg_str)
      #Verify Sign
      unless self.digital_sign(msg,"public","verify")
        msg["Body"] = "Bad Sign\r\n\r\n#{msg["Body"]}"
        msg["Msg-sign"] = "Bad Sign"
      end
      if msg.has_key?("Control") && msg["Msg-sign"] != "Bad Sign"
        unless self.parse_cmsg(msg)
          self.response("437 Article rejected - do not try again")
        end
      end
      tags = msg["Newsgroups"].split(",")
      active = DBM::open("#{$fns_path}/db/active",0666)
      tags.each do |t|
        unless active.has_key?(t)
          tags.delete(t)
        end
      end
      msg["Path"] = "#{@socket.addr[2]}!#{msg["Path"]}"
      msg["Xref"] = @socket.addr[2]
      tag.each do |t|
        msg["Xref"] += "\s" + t + ":" + self.calc_artnum(t)
      end
      if msg["Newsgroups"] == "control"
        main_artnum = self.calc_artnum("control")
        path =  "#{$fns_path}/article/control/#{main_artnum}"
      else
        main_artnum = self.calc_artnum("all")
        path =  "#{$fns_path}/article/#{main_artnum}"
      end
      File.open(path,"w") do |f|
        f.write self.to_str(msg)
      end
      self.append_hist(msg,main_artnum)
      self.create_artnum(tag,main_artnum)
      puts "nntpserver:Article <#{msg["Message-ID"]}> transferred ok"
      self.response("235 Article transferred OK")
      #feed message
      $fns_queue.push("#{main_artnum},#{msg["Newsgroups"]}")
      return
   end

    #Control message parese
    def parse_cmsg(msg)
      cmd,param = msg["Control"].split("\s",2)
      case cmd
      when "cancel"
        if self.chk_hist?(param)
          history = DBM::open("#{$fns_path}/db/history",0666)
          return "Alreday canceled" if history[param] == "Canceled"
          tag = history[param].split("!")[5].split("\s",2)[1].split("\s")
          tag.each do |t|
            tags,art_num = t.split(":") 
            if File.exist?("#{$fns_path}/article/#{tags}/#{art_num}")
              delmsg = self.to_hash(File.read("#{$fns_path}/article/#{tags}/#{art_num}"))
              if msg["From"] == delmsg["From"]
                File.delete("#{$fns_path}/article/#{tags}/#{art_num}")
              else
                #wrong auther
                return "Wrong auther"
              end
              #change history file
              history[param] = "Canceled"
              #change tag file

              return true
            end
          end
        else
          #add contrl 
          ctl_hist = DBM::open("#{$fns_path}/db/ctl_hist",0666)
          ctl_hist[param] = "param"
          return true
        end
      when "newtag"
        active = DBM::open("#{$fns_path}/db/active",0666)
        return nil if active.has_key?(param)
        history = DBM::open("#{$fns_path}/db/history",0666)
        sub_artnum = DBM::open("#{$fns_path}/db/tags/#{param}",0666)
        cnt = 0 #article number
        history.each_key do |k|
          tags = history[k].split("!")[7].split(",")
          artnum = history[k].split("!")[0]
          tags.each do |t|
            if t == param
              cnt += 1
              sub_artnum[cnt.to_s] = artnum
            end
          end
        end
        if cnt == 0
          active[param] = "0,0,y,0"
        else
          active[param] = "1,#{cnt.to_s},y,#{cnt.to_s}"
        end
        return true
      when "rmtag"
        return true
      else
        return nil
      end
    end

    def calc_artnum(tag)
      active = DBM::open("#{$fns_path}/db/active",0666)
      p active[tag]
      num = (active[tag].split(",")[1].to_i + 1).to_s # first article number,last article number,post,number
      return num
    end

    def sach_main_artnum(tag,sub_artnum)
      tags = DBM::open("#{$fns_path}/db/tags/#{tag}",0666)
      return tags[sub_artnum]
    end

    def create_artnum(tags,main_num)
      active = DBM::open("#{$fns_path}/db/active",0666)
      tags.each do |t|
        flag == 1 if t == "control"
        sub_artnum = DBM::open("#{$fns_path}/db/tags/#{t}",0666)
        min_artnum,max_artnum,p,num = active[t].split(",")
        unless n == "0"
          max_artnum = (max_artnum.to_i + 1).to_s
        else
          min_artnum = (min_artnum.to_i + 1).to_s
          max_artnum = (max_artnum.to_i + 1).to_s
        end
        n = (n.to_i + 1).to_s
        sub_artnum[max_artnum] = main_num
        sub_artnum.close
        active[t] = min_artnum + "," + max_artnum + "," +  p + "," + n
      end
      self.create_artnum("all",main_num) unless tags.includ("control")
    end

    def append_history(msg,art_num)
      history = DBM::open("#{$fns_path}/db/history",0666)
      history[msg["Message-ID"]] = "#{art_num}!#{msg["Subject"]}!#{msg["From"]}!#{msg["Date"]}!#{File.size("#{$fns_path}/article/#{art_num}")}!#{msg["Lines"]}!#{msg["Xref"]}!#{msg["Newsgroups"]}"
      history.close
      if msg["Newsgroups"] == "control"
        filename = "artnum_msg_id_ctl"
      else
        filename = "artnum_msg_id"
      end
      msg_id = DBM::open("#{$fns_path}/db/#{filename}",0666)
      msg_id[art_num] = msg["Message-ID"]
      msg_id.close
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

    #Covert hash table to sring
  	def to_str(msg_hash)
	  	msg = ""
  		i = 1
  		headers = DBM::open("#{$fns_path}/db/headers",0666)
  		while i <= headers.length
  			unless headers[i.to_s] == "Body"
  				if msg_hash[headers[i.to_s]]
  					msg += headers[i.to_s] + ":\s" + msg_hash[headers[i.to_s]] + "\r\n"
  				end
  			else
          msg += "\r\n"
  				msg += msg_hash[headers[i.to_s]]
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

    #Digital sign
	  def digital_sign(msg,rsakey,action)
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
			  key = OpenSSL::PKey::RSA.new(File.read("#{$fns_path}/openssl/#{rsakey}.key"))	
	 	    digest = OpenSSL::Digest::SHA1.new()
			  case action
			  when "sign"
          puts "nntpserver:Starting sign message #{msg["Message-ID"]} with private key"
				  msg_sign = Base64.b64encode(key.sign(digest,File.read("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}"))).delete("\n")
          #del tmp file
          File.delete("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}")
          puts "nntpserver:Sign message#{msg["Message-ID"]} with private key ok"
				  return msg_sign
			  when "verify"
          print "nntpserver:Starting verify message#{msg["Message-ID"]}..."
				  if key.verify(digest,Base64.decode64(msg["Msg-Sign"]),File.read("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}"))
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{msg["Message-ID"]}.#{action}")
            puts "nntpserver:Verify message#{msg["Message-ID"]} with public key ok"
					  return true
				  else
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{msg["Nessage-ID"]}.#{action}")
					  puts "nntpserver:Bad sign"
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
  end
end
