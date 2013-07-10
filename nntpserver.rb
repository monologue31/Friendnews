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

		    puts "nntpserver:accepted #{conn.addr[2]}"

        #check 127.0.0.1
        if true
			    Thread.start do
            conn.puts(200)
			      process = NNTPProcess.new(conn)
			      process.run
			      puts "nntpserver:#{conn.addr[2]} done"
			    end
        else
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
          puts "nntpserver:connection closed #{sock.addr[2]}"
        end
        
        begin
          while line = @socket.gets
            puts "nntpserver:received command [#{line.chomp}]"
            next unless line
            cmd,param = line.split(/\s+/,2)
            param = param.chomp
            case cmd
            when /(?i)post/
            #user check
            if true
              self.response("340 sent article to be posted.end with <.>")
              self.response(self.rcv_msg("post",msg_id = nil,contrl = gpsel))
            else
              self.response("440 posting not allowed")
            end
            when /(?i)ihave/
              unless true #check tag
                self.response("435 article not wanted - do not send it")
                next
              end

              if self.chk_hist?(param)
                self.response("335 send article to be transferred.end with <.>")
                self.response(self.rcv_msg("ihave",msg_id = param))
              else
                self.response("437 article rejected - do not try again")
              end
            when "MODE"
              if param.chomp == "READER"
                post_a = true
                self.response("200 news server ready - posting ok")
              else
                post_a = nil
                self.response("201 news server ready - posting not allowed")
              end
            when /(?i)list/
              self.response("215 list of newsgroups follows")
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
                self.response("412 no news group current selected")
                next
              end
              self.response(".")
            when /(?i)article/
              unless gpsel
                self.response("412 no newsgroup has been selected")
                next
              end

              if param
                art = DBM.open("#{$fns_path}/article/#{gpsel}/article_number",0666)
                if /<.*>/ =~ param
                  num = art.key(param)
                  msg_id = param
                else
                  num = param
                  msg_id = art[num]
                end
                art.close
                if File.exist?("#{$fns_path}/article/#{gpsel}/#{msg_id}")
                  self.response("220 #{num} #{msg_id} article retrieved - head and boy follow")
                  msg = File.open("#{$fns_path}/article/#{gpsel}/#{msg_id}")
                  while line = msg.gets
                    #self.response(line)
                    @socket.puts(line)
                  end
                  self.response(".")
                else
                  self.response("423 no such article number in this group")
                  next
                end
              else
                self.response("420 no current article has been selected")
              end
            when /(?i)quit/
			        puts "nntpserver:connection closed #{@socket.addr[2]}"
              @socket.close
              return
            else
              self.response("500 command not recognized")
            end
          end
	  	  rescue => e
		  	  puts e.to_s
		  	  @socket.close
        end
      end
		end

    def response(res)
      puts "nntpserver:sent response [#{res}]"
      @socket.puts(res)
    end

    def rcv_msg(cmd,msg_id = nil,contrl = nil)
      msg_str = ""
      while line = @socket.gets
        break if line == ".\r\n"
        msg_str += line
      end

      case cmd
      when /(?i)post/
        message = self.to_hash(msg_str)

        #add Message-ID
        message["Message-ID"] = UUIDTools::UUID.random_create().to_s + "@" + message["From"]

        #add Path
        message["Path"] = @socket.addr[2] unless message.key?("Path")

        #add Signature
        message["Signature"] = "From,Subject,Message-ID"

        #add Expires

        #add Date
        message["Date"] = Time.now.to_s unless message.key?("Date")

        #add Xref
        message["Xref"] = self.append_tag(message)

        tag = message["Newsgroups"].split(",")
        tag.each do |t|
          File.open("#{$fns_path}/article/#{t}/#{message["Message-ID"]}","w") do |f|
            f.write self.to_str(message)
          end
        end

        #append history
        self.append_history(messsage)

        puts "nntpserver:Receive messsage[#{message["Message-ID"]}] successful"
        #feed message
        code = "240 article posted ok"

        #parse contrl message
        if contrl == "Contrl"
          self.contrl(message["Subject"],message["Body"])
        end

        tag.each do |t|
          #sign msg
          p t
          self.openssl(message["Message-ID"],t,"private","sign")
          #self.openssl(message["Message-ID"],message["Newsgroups"],"public","verify")
          #self.feed(message["Message-ID"],message["Newsgroups"])
        end
	  		return code
      when /(?i)ihave/
        message = self.to_hash(msg_str)
        
	  		#add Path
	  		message["Path"] += "!#{@socket.addr[2]}"

        p message

        File.open("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message-ID"]}.tmp","w") do |f| 
          f.write self.to_str(message)
        end

        #check verify
        self.openssl(message["Message-ID"],message["Newsgroups"],"public","verify")

        #save file
        File.open("#{$fns_path}/article/#{message["Newsgroups"]}/#{message["Message-ID"]}","w") do |f| 
          f.write File.read("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message-ID"]}.tmp")
        end

        #del tmp file
        File.delete("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message-ID"]}.tmp")
        
        #append history
        self.append_history(message)

        #feed message
        self.feed(message["Message-ID"],message["Newsgroups"])
        return code
      end
    end

    def contrl(type,command)
      case type
      when "Delet messgae"
      when "New tag"
        FileUtils.mkpath("article/#{tagname}")
        FileUtils.mkpath("tmp/#{tagname}")
        fnstag = DBM::open("#{$fns_path}/db/fnstag",0666)
        fnstag[tagname] = "0,0,#{p},0"
        fnstag.close
      when "Delete tag"
      else
      end
    end

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

        #append history
        art[la] = message["Message-ID"]
        art.close
        fnstags[t] = fa + "," + la + "," +  p + "," + n
        p t
        p fnstags[t]
        fnstags.close
        msg_xref += "\s" + t + ":" + la
      end
      return msg_xref
    end

    def append_history(message)
      history = DBM::open("#{$fns_path}/db/history",0666)
      history[message["Message-ID"]] = "#{message["Subject"]}!#{message["From"]}!#{message["Date"]}!#{File.size("#{$fns_path}/article/#{tag[0]}/#{message["Message-ID"]}")}!#{message["Lines"]}!#{message["Xref"]}!#{message["Newsgroups"]}"
      history.close
    end
    def chk_hist?(message_id)
			history = DBM::open("#{$fns_path}/db/history",0666)
			
			if history.value?(message_id)
				puts "nntpserver:message_id<#{message_id}> already in history..."
				history.close
				return nil
			else
				puts "nntpserver:message_id<#{message_id}> not in history..."
				history.close
				return 1
			end
    end

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


	def openssl(msg_id,tag,rsakey,action)
		begin
		  tmpfile = File.open("#{$fns_path}/tmp/#{tag}/#{msg_id}#{action}.tmp","w+")
      message = self.to_hash(File.read("#{$fns_path}/article/#{tag}/#{msg_id}")) 
		  sign_headers = message["Signature"].split(",")
	
		  i = 0
		  while i<=sign_headers.length-1
			  tmpfile.puts(sign_headers[i] + ":\s" + message[sign_headers[i]])
			  i+=1
		  end

		  tmpfile.puts(message["Body"])

			key = OpenSSL::PKey::RSA.new(File.read("#{$fns_path}/openssl/#{rsakey}.key"))	
	 	  digest = OpenSSL::Digest::SHA1.new()

			case action
			when "sign"
				message["Msg-Sign"] = Base64.b64encode(key.sign(digest,File.read("#{$fns_path}/tmp/#{tag}/#{msg_id}#{action}.tmp"))).delete("\n")

        File.open("#{$fns_path}/article/#{tag}/#{message["Message-ID"]}","w") do |f|
          f.write self.to_str(message)
        end

        tmpfile.close
				return 1
			when "verify"
				if key.verify(digest,Base64.decode64(message["Msg-Sign"]),File.read("#{$fns_path}/tmp/#{tag}/#{msg_id}#{action}.tmp"))
          tmpfile.close
					return 1
				else
					puts "bad sign"
          tmpfile.close
					return nil
				end
			else
			end
		rescue => e
			puts e.to_s
			return 1
		end
	end

end

end
