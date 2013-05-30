require 'socket'
require 'dbm'
require 'rubygems'
require 'uuidtools'
require "fileutils"

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
            puts line
            next unless line
            cmd,param = line.split(/\s+/,2)
            param = param.chomp
            case cmd
            when /(?i)post/
            #user check
            if true
              self.response("340 sent article to be posted.end with <.>")
              self.response(self.rcv_msg("post",msg_id = nil))
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
              p param
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
                    fields = history[art[f.to_s]].split(",")
                    res = "#{f.to_s}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t#{art[f.to_s]}\t#{fields[3]}\t#{fields[4]}#{fields[5]}"
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
                art = DBM.open("#{$fns_path}/#{gpsel}/article_number")
                if /<.*>/ =~ param
                  num = art.key(param)
                  msg_id = param
                else
                  num = param
                  msg_id = art[num]
                end
                art.close
                if File.exist?("#{$fns_path}/#{gpsel}/#{param}")
                  self.response("220 #{num} #{msg_id} article retrieved - head and boy follow")
                  msg = File.open("#{$fns_path}/#{gpsel}/#{param}")
                  while line = msg.gets
                    self.response(line)
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
              stat_code += 500
            end
          end
	  	  rescue => e
		  	  puts e.to_s
		  	  @socket.close
        end
      end
		end

    def response(res)
      puts res
      @socket.puts(res)
    end

    def rcv_msg(cmd,msg_id = nil)
      msg_str = ""
      while line = @socket.gets
        break if line == ".\r\n"
        msg_str += line
      end

      case cmd
      when /(?i)post/
        message = self.to_hash(msg_str)
    
  			#add Message_id
  			message["Message_id"] = UUIDTools::UUID.random_create().to_s + "@" + message["From"] unless message.key?("Message_id")

	  		#add Path
	  		message["Path"] = @socket.addr[2] unless message.key?("Path")

	  		#add Signature
	  		#unless message.key?("Signature")
	  		#	option = DBM::open("#{$fns_path}/db/option",0666)
	  		#	message["Signature"] = option["Signature"]
	  		#	option.close
	  		#end

        #sign msg

		  	#add Expires

	  		#add Lines
	  		#message["Lines"] = (msg_line -= 1).to_s unless message.key?("Lines")

	  		#add Date
	  		message["Date"] = Time.now.to_s unless message.key?("Date")

        File.open("#{$fns_path}/article/#{message["Newsgroups"]}/#{message["Message_id"]}","w") do |f|
          f.write self.to_str(message)
        end

        #append history
        self.append_history(message)

        puts "nntpserver:Receive messsage[#{message["Message_id"]}] successful"
        #feed message
        self.feed(message["Message_id"],message["Newsgroups"])
        code = 240
	  		return code
      when /(?i)ihave/
        message = self.to_hash(msg_str)
        
	  		#add Path
	  		message["Path"] += "!#{@socket.addr[2]}"

        p message

        File.open("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message_id"]}.tmp","w") do |f| 
          f.write self.to_str(message)
        end

        #check verify

        #save file
        File.open("#{$fns_path}/article/#{message["Newsgroups"]}/#{message["Message_id"]}","w") do |f| 
          f.write File.read("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message_id"]}.tmp")
        end

        #del tmp file
        File.delete("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message_id"]}.tmp")
        
        #append history
        self.append_history(message)

        #feed message
        self.feed(message["Message_id"],message["Newsgroups"])
        return code
      end
    end

    def feed(message_id,tag)
      feed = File.open("#{$fns_path}/etc/fnsfeed.conf")
      while line = feed.gets
        host,host_id,host_tag = line.split("!")
        if /#{tag}/ =~ host_tag
          puts "nntpserver:Feed message[#{message_id}]"
          $fns_queue.push("#{host_id}!#{message_id},#{tag}")
        end
      end
    end

    def append_history(message)
      history = DBM::open("#{$fns_path}/db/history",0666)
      art = DBM::open("#{$fns_path}/article/#{message["Newsgroups"]}/article_number",0666)
      fnstags = DBM::open("#{$fns_path}/db/fnstags",0666)
      fa,la,p,n = fnstags[message["Newsgroups"]].split(",")
      unless n.to_i == 0 
        num = la.to_i + 1
  
        if art.key?(num.to_s)
          num += 1 
        end
        la = num.to_s
      end
      n = (n.to_i + 1).to_s

      #append history
      art[num.to_s] = message["Message_id"]
      art.close
      history[message["Message_id"]] = "#{message["Subject"]},#{message["From"]},#{message["Date"]},#{File.size("#{$fns_path}/tmp/#{message["Newsgroups"]}/#{message["Message_id"]}")},#{message["line"]},#{message["Xref"]},#{message["Newsgroups"]}"
      p histroy[message["Message_id"]]
      history.close
      fnstags[message["Message_id"]] = la + "," + fa + "," +  p + "," + n
      fnstags.close
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
				unless line[i] = ""
          header_field,field_value = line[i].split(/\s*:\s*/,2)
					message[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end

      p message

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

    def creat_tag(tagname,p)
      FileUtils.mkpath("article/#{tagname}")
      FileUtils.mkpath("tmp/#{tagname}")
      fnstag = DBM::open("#{$fns_path}/db/fnstag",0666)
      fnstag[tagname] = "0000000000,0000000000,#{p},0"
      fnstag.close
    end
  end

end
