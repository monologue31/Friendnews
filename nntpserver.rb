require 'socket'
require 'dbm'
require 'rubygems'
require 'uuidtools'

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
          case cmd
          when "MODE"
            p cmd
            if param == "READER"
              @socket.puts("200 Hello,you can post")
            end
          when /(?i)post/
            stat_code += 40
            #user check
            if true
              stat_code += 300
              @socket.puts(stat_code)
              @socket.puts(self.rcv_msg("post",msg_id = nil))
            else
              stat_code += 400
              @socket.puts(stat_code)
            end
          when /(?i)ihave/
            stat_code += 30
            if self.chk_hist?(param)
              stat_code += 305
              @socket.puts(stat_code)
              @socket.puts(self.rcv_msg("ihave",msg_id = param))
            else
              stat_code += 400
              @socket.puts(stat_code)
            end
          when /(?i)article/
          when /(?i)list/
            tag = File.open("#{$fns_path}/etc/fnstags.conf")
            @socket.puts(215)
            while line = tag.gets
              puts "nntpserver:Response Tag [#{line}]"
              @socket.puts(line)
            end
            @socket.puts(".")
          when /(?i)group/
            #group option
            res = "211 2 00000 00001 #{param.chomp} group selected"
            p res
            @socket.puts(res)
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

    def rcv_msg(cmd,msg_id = nil)
      msg_str = ""
      while line = @socket.gets
        p line
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
	  		#	option = DBM::open("#{$fns_path}/db/option",0066)
	  		#	message["Signature"] = option["Signature"]
	  		#	option.close
	  		#end

        #sign msg

		  	#add Expires

	  		#add Lines
	  		#message["Lines"] = (msg_line -= 1).to_s unless message.key?("Lines")

	  		#add Date
	  		message["Date"] = Time.now.to_s unless message.key?("Date")

        File.open("#{$fns_path}/article/#{message["Tag"]}/#{message["Message_id"]}","w") do |f|
          f.write self.to_str(message)
        end

        puts "nntpserver:Receive messsage[#{message["Message_id"]}] successful"
        #feed message
        self.feed(message["Message_id"],message["Tag"])
        code = 240
	  		return code
      when /(?i)ihave/
        message = self.to_hash(msg_str)
        
	  		#add Path
	  		message["Path"] += "!#{@socket.addr[2]}"

        p message

        File.open("#{$fns_path}/tmp/#{message["Tag"]}/#{message["Message_id"]}.tmp","w") do |f| 
          f.write self.to_str(message)
        end

        #check verify

        #save file
        File.open("#{$fns_path}/article/#{message["Tag"]}/#{message["Message_id"]}","w") do |f| 
          f.write File.read("#{$fns_path}/tmp/#{message["Tag"]}/#{message["Message_id"]}.tmp")
        end

        #del tmp file
        File.delete("#{$fns_path}/tmp/#{message["Tag"]}/#{message["Message_id"]}.tmp")
        #feed message
        self.feed(message["Message_id"],message["Tag"])
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

    def history()
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
  		header = DBM::open("#{$fns_path}/db/header",0066)

  		while i<=header.length
  			unless header[i.to_s] == "Body"
  				if message_hash[header[i.to_s]]
  					string += header[i.to_s] + ":\s" + message_hash[header[i.to_s]] + "\n"
  				end
  			else
          string += "\n"
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
          if header_field == "Newsgroups"
            message["Tag"] = field_value
          else
					  message[header_field] = field_value
          end
          i += 1
				else
          i += 1
          break
				end
      end

      msg_line = 0
      while i < line.length
		   	message["Body"] += "#{line[i]}\n"
        break if line[i] == "."
		  	msg_line += 1
        i += 1 
      end

      message["Lines"] = msg_line.to_s
	  	return message
  	end

  end

end
