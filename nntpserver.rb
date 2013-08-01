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

        #check 127.0.0.1
        if conn.addr[3] == "127.0.0.1"
          puts "nntpserver:Accepted connection from #{conn.addr[2]}"
			    Thread.start do
            conn.puts(200)
			      process = NNTPProcess.new(conn)
			      process.run
			      puts "nntpserver:#{conn.addr[2]} done"
			    end
        else
          puts "nntpserver:Refuse connection from #{conn.addr[2]}"
          conn.puts("You do not have the premision to connect this server!")
          conn.close
        end
      end
    end

    def log
    end
  end

  class NNTPProcess
	  def initialize(socket)
		  @socket = socket
      @stat_code = 0
      @message = Hash.new
	  end

    def run
      #initialize
      stat_code = 0
      gpsel = nil
      post_a = nil
      loop do
        if @socket.eof?
          @socket.close
          puts "nntpserver:Connection closed by #{sock.addr[2]}"
        end
        
        begin
          while line = @socket.gets
            puts "nntpserver:Received request [#{line.chomp}]"
            next unless line
            cmd,param = line.split(/\s+/,2)
            param = param.chomp
            case cmd
            when /(?i)post/
            #user check
            if true
              self.response("340 Sent article to be posted.end with <.>")
              self.response(self.rcv_msg("post",msg_id = nil,contrl = gpsel))
            else
              self.response("440 Posting not allowed")
            end
            when /(?i)ihave/
              unless true #check tag
                self.response("435 Article not wanted - do not send it")
                next
              end

              unless self.chkhist?(param)
                self.response("335 Send article to be transferred.end with <.>")
                self.response(self.rcv_msg("ihave",msg_id = param))
              else
                self.response("437 Article rejected - do not try again")
              end
            when "MODE"
              if param.chomp == "READER"
                post_a = true
                self.response("200 News server ready - posting ok")
              else
                post_a = nil
                self.response("201 News server ready - posting not allowed")
              end
            when /(?i)list/
              self.response("215 List of newsgroups follows")
              fnstags = DBM.open("#{$fns_path}/db/fnstags",0666)
              fnstags.each_key{|s|
                fa,la,p = fnstags[s].split(",")
                res = s + "\s" + la + "\s" + fa + "\s" + p
                self.response(res)
              }
              self.response(".")
              fnstags.close
            when /(?i)group/
              fnstags = DBM.open("#{$fns_path}/db/fnstags",0666)
              fa,la,p,n = fnstags[param].split(",")
              res = "211 #{n} #{fa} #{la} #{param} group selected"
              gpsel = param
              self.response(res)
              fnstags.close
            when /(?i)xover/
              #find message
              if gpsel
                f,l = param.split("-")
                f = f.to_i
                if l
                  l = l.to_i
                else
                  fnstags = DBM.open("#{$fns_path}/db/fnstags",0666)
                  a = fnstags[gpsel].split(",")
                  l = a[0].to_i
                  fnstags.close
                end
                self.response("224 #{param} fields follow")
                art = DBM.open("#{$fns_path}/article/#{gpsel}/article_number")
                history = DBM::open("#{$fns_path}/db/history",0666)
                while f <= l
                  if art.key?(f.to_s)
                    fields = history[art[f.to_s]].split("!")
                    res = "#{f.to_s}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t#{art[f.to_s]}\t#{fields[3]}\t#{fields[4]}\t#{fields[5]}"
                    self.response(res)
                  end
                  f += 1
                end
              else
                self.response("412 No news group current selected")
                next
              end
              self.response(".")
            when /(?i)article/
              unless gpsel
                self.response("412 No newsgroup has been selected")
                next
              end

              if param
                if File.exist?("#{$fns_path}/article/#{gpsel}/#{param}")
                  self.response("220 #{param} #{msg_id} article retrieved - head and boy follow")
                  msg = File.open("#{$fns_path}/article/#{gpsel}/#{param}")
                  while line = msg.gets
                    #self.response(line)
                    @socket.puts(line)
                  end
                  self.response(".")
                else
                  self.response("423 No such article number in this group")
                  next
                end
              else
                self.response("420 No current article has been selected")
              end
            when /(?i)quit/
			        puts "nntpserver:Connection closed by #{@socket.addr[2]}"
              @socket.close
              return
            else
              self.response("500 Command not recognized")
            end
          end
		    rescue => e
		      puts e.to_s
          @socket.close
        end
      end
		end

    #Response
    def response(res)
      puts "nntpserver:Sent response [#{res}]"
      @socket.puts(res)
    end

    #Response message
    def rcv_msg(cmd,msg_id = nil,contrl = nil)
      begin
        msg_str = ""
        while line = @socket.gets
          break if line == ".\r\n"
          msg_str += line
        end

        case cmd
        when /(?i)post/
          message = self.to_hash(msg_str)

          #add Message-ID
          message["Message-ID"] = "<#{UUIDTools::UUID.random_create().to_s}@#{message["From"].split(" ")[0]}>"

          #add Path
          message["Path"] = @socket.addr[2] unless message.key?("Path")

          #add Signature
          message["Signature"] = "From,Subject,Message-ID"

          #add Expires

          #add Date
          message["Date"] = Time.now.to_s unless message.key?("Date")

          #add Xref
          message["Xref"] = self.append_tag(message)

          #Control message
          if message.has_key?("Control") 
            unless self.parse_cmsg(message)
              code = ""
              return code
            end
          end

          #sign msg
          message = self.openssl(message,"private","sign")
          tag = message["Xref"].split("\s",2)[1].split("\s")
          #tag = message["Newsgroups"].split(",")
          tag.each do |t|
            tags,art_num = t.split(":") 
            File.open("#{$fns_path}/article/#{tags}/#{art_num}","w") do |f|
              f.write self.to_str(message)
            end
          end

          #append history
          self.append_history(message)

          puts "nntpserver:Article <#{message["Message-ID"]}> posted ok"
          #feed message
          code = "240 Article posted ok"

          tag.each do |t|
          end

          #self.feed(message["Message-ID"],message["Newsgroups"])
          return code
        when /(?i)ihave/
          message = self.to_hash(msg_str)

          #check verify
          unless self.openssl(message,"public","verify")
            message["Body"] = "Bad Sign\r\n\r\n#{message["Body"]}"
            message["Msg-sign"] = "Bad Sign"
          else
            #Control message
            if message.has_key?("Control") 
              unless self.parse_cmsg(message)
                code = ""
                return code
              end
            end
          
            #add Path
            message["Path"] = "#{@socket.addr[2]}!#{message["Path"]}"
          end

          #add Xref
          message["Xref"] = self.append_tag(message)

          #save file
          tag =message["Xref"].split("\s",2).split("\s")
          #tag = message["Newsgroups"].split(",")
          tag.each do |t|
            tags,art_num = t.split(":") 
            File.open("#{$fns_path}/article/#{tags}/#{art_num}","w") do |f|
              f.write self.to_str(message)
            end
          end

          #append history
          self.append_history(message)

          puts "nntpserver:Article <#{message["Message-ID"]}> transferred ok"

          code = "235 Article transferred successfully.Thanks"
          #feed message
          self.feed(message["Message-ID"],message["Newsgroups"]) if message["Msg-sign"] != "Bad Sign"
          return code
        end
      rescue =>e
        puts e.to_s
        code = "441 Posting failed"
        return code 
      end
    end

    #Control message parese
    def parse_cmsg(message)
      cmd,param = message["Control"].split(" ",2)
      case cmd
      when "cancel"
        if self.chkhist?(param)
          history = DBM::open("#{$fns_path}/db/history",0666)
          return "Alreday canceled" if history[param] == "Canceled"
          tag = history[param].split("!")[5].split("\s",2)[1].split("\s")
          tag.each do |t|
            tags,art_num = t.split(":") 
            if File.exist?("#{$fns_path}/article/#{tags}/#{art_num}")
              delmsg = self.to_hash(File.read("#{$fns_path}/article/#{tags}/#{art_num}"))
              if message["From"] == delmsg["From"]
                delmsg.close
                p "des msg"
                FileUtils.rm("#{$fns_path}/article/#{t}/#{param}")
                p "des ok"
              else
                #wrong auther
                return "Wrong auther"
              end
              #change history file
              history[param] = "Canceled"
              #change tag file

              return 1
            end
          end
        else
          #add contrl 
          ctl_hist = DBM::open("#{$fns_path}/db/ctl_hist",0666)
          ctl_hist[param] = "param"
          return 1
        end
      when "newtag"
        FileUtils.mkpath("article/#{parm}")
        FileUtils.mkpath("tmp/#{parm}")
        fnstag = DBM::open("#{$fns_path}/db/fnstag",0666)
        fnstag[param] = "0,0,#{p},0"
        fnstag.close
        return 1
      when "rmtag"
        FileUtils.rm("article/#{parm}")
        FileUtils.rm("tmp/#{parm}")
        fnstag = DBM::open("#{$fns_path}/db/fnstag",0666)
        fnstag.delete(parm)
        fnstag.close
        return 1
      else
        return nil
      end
    end

    #News feeds
    def feed(msg_id,tag)
      feed = File.open("#{$fns_path}/etc/fnsfeed.conf")
      while line = feed.gets
        host,host_id,host_tag = line.split("!")
        if /#{tag}/ =~ host_tag
          puts "nntpserver:Feed message[#{msg_id}]"
          $fns_queue.push("#{host_id}!#{msg_id},#{tag}")
        end
      end
    end

    #Append xref header and tag file
    def append_tag(message)
      msg_xref = @socket.addr[2]
      tag = message["Newsgroups"].split(",")
      tag.each do |t|
        art = DBM::open("#{$fns_path}/article/#{t}/article_number",0666)
        fnstags = DBM::open("#{$fns_path}/db/fnstags",0666)
        fa,la,p,n = fnstags[t].split(",")
        unless n == "0"
          la = (la.to_i + 1).to_s
          if art.key?(la)
            la = (la.to_i + 1).to_s
          end
        else
          fa = (fa.to_i + 1).to_s
          la = (la.to_i + 1).to_s
        end
        n = (n.to_i + 1).to_s

        art[la] = message["Message-ID"]
        art.close
        fnstags[t] = fa + "," + la + "," +  p + "," + n
        fnstags.close
        msg_xref += "\s" + t + ":" + la
      end
      return msg_xref
    end

    def append_history(message)
      history = DBM::open("#{$fns_path}/db/history",0666)
      history[message["Message-ID"]] = "#{message["Subject"]}!#{message["From"]}!#{message["Date"]}!#{File.size("#{$fns_path}/article/#{message["Newsgroups"].split(",")[0]}/#{message["Xref"].split("\s")[1].split(":")[2]}")}!#{message["Lines"]}!#{message["Xref"]}!#{message["Newsgroups"]}"
      history.close
    end

    def chkhist?(message_id)
			history = DBM::open("#{$fns_path}/db/history",0666)
			
			if history.has_key?(message_id)
				puts "nntpserver:message_id<#{message_id}> already in history"
				history.close
				return 1
			else
				puts "nntpserver:message_id<#{message_id}> not in history"
				history.close
				return nil
			end
    end

    #Covert hash table to sring
  	def to_str(message_hash)
	  	string = ""
  		i=1
  		header = DBM::open("#{$fns_path}/db/header",0666)

  		while i<=header.length
  			unless header[i.to_s] == "Body"
  				if message_hash[header[i.to_s]]
  					string += header[i.to_s] + ":\s" + message_hash[header[i.to_s]] + "\r\n"
  				end
  			else
          string += "\r\n"
  				string += message_hash[header[i.to_s]]
  			end
  			i+=1
  		end	

  		return string
  	end

    #Covert string to hash table
  	def to_hash(string)
      i = 0
      message = Hash.new
      message["Body"] = ""
      line = string.split("\r\n")
      while i < line.length
				unless line[i] == ""
          header_field,field_value = line[i].split(/\s*:\s*/,2)
					message[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end

      msg_line = 0
      while i < line.length
		   	message["Body"] += "#{line[i]}\r\n"
        break if line[i] == "."
		  	msg_line += 1
        i += 1 
      end

      message["Lines"] = msg_line.to_s

	  	return message
  	end

    #Digital sign
	  def openssl(message,rsakey,action)
		  begin
		    tmpfile = File.open("#{$fns_path}/tmp/#{message["Message-ID"]}#{action}.tmp","w+")
		    sign_headers = message["Signature"].split(",")
	
		    i = 0
		    while i<=sign_headers.length-1
			    tmpfile.puts(sign_headers[i] + ":\s" + message[sign_headers[i]])
			    i+=1
		    end

		    tmpfile.puts(message["Body"])

			  key = OpenSSL::PKey::RSA.new(File.read("#{$fns_path}/openssl/#{rsakey}.key"))	
	 	    digest = OpenSSL::Digest::SHA1.new()
        tmpfile.close

			  case action
			  when "sign"
          puts "nntpserver:Starting sign message#{message["Message-ID"]} with private key"
				  message["Msg-Sign"] = Base64.b64encode(key.sign(digest,File.read("#{$fns_path}/tmp/#{message["Message-ID"]}#{action}.tmp"))).delete("\n")
          #del tmp file
          File.delete("#{$fns_path}/tmp/#{message["Message-ID"]}#{action}.tmp")
          puts "nntpserver:Sign message#{message["Message-ID"]} with private key ok"
				  return message
			  when "verify"
          print "nntpserver:Starting verify message<#{message["Message-ID"]}>..."
				  if key.verify(digest,Base64.decode64(message["Msg-Sign"]),File.read("#{$fns_path}/tmp/#{message["Message-ID"]}#{action}.tmp"))
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{message["Message-ID"]}#{action}.tmp")
            puts "nntpserver:Verify message#{message["Message-ID"]} with public key ok"
					  return 1
				  else
            #del tmp file
            File.delete("#{$fns_path}/tmp/#{message["Nessage-ID"]}#{action}.tmp")
					  puts "nntpserver:Bad sign"
					  return nil
				  end
			  else
			  end
		  rescue => e
			  puts e.to_s
			  return nil
		  end
	end

end

end
