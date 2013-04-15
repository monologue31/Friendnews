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
      puts "NNTP Server Started"
	  	loop do
		  	socket = @socket.accept
	
		  	puts "server:accepted #{socket.addr[2]}"

		  	Thread.start do
		  	process = NNTPProcess.new(socket)
		  	process.run
		  	puts "server:#{socket.addr[2]} done"
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
	  	if @socket.eof?
		  	@socket.close
			  puts "connection closed #{sock.addr[2]}"
		  end

	  	begin
        loop do
          while line = @socket.gets
            cmd,param = line.split(/\s+/,2)
            case cmd
            when /(?i)post/
              @stat_code += 30
              #user check
              if true
                @stat_code += 300
                self.send_res(@stat_code)
                self.send_res(self.rcv_msg("post",msg_id = nil))
              else
                @stat_code += 400
                break
              end
            when /(?i)ihave/
              @stat_code += 40
              if self.chk_hist?()
                @stat_code += 300
                self.send_res(@stat_code)
                self.send_res(self.rcv_msg(ihave,msg_id = param))

              else
                @stat_code += 400
                break
              end
            when /(?i)quit/
              break
            else
              @stat_code += 500
              break
            end
          end
        end
	  	rescue => e
		  	puts e.to_s
		  	@socket.close
      end
		end

    def rcv_msg(cmd,msg_id = nil)
      msg_str = ""
      while line = @socket.gets
        msg_str += line
        if line == ".\n"
          break
        end
      end
 
      p msg_str
      case cmd
      when /(?i)post/
        message = self.to_hash(msg_str)
    
        p message
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

        p message
        File.open("#{$fns_path}/article/#{message["Tag"]}/#{message["Message_id"]}","w") do |f|
          f.write self.to_str(message)
        end

        #feed message
        self.feed(message["Message_id"],message["Tag"])
        code = 240
	  		return code
      when /(?i)ihave/
        tag = msg_str.scan(/Tag\s*:\s*.*\n/)[0].split(/\s*:\s*/)[1].chomp
        File.open("#{$fns_path}/tmp/#{tag}}/#{msg_id.tmp}","w") do |f| 
          f.print msg_str
        end

        #check verify

        #save file
        File.open("#{$fns_path}/article/#{tag}}/#{msg_id}") do |f| 
          f.print File.read("#{$fns_path}/tmp/#{tag}}/#{msg_id.tmp}")
        end

        #feed message
        return code
      end
    end

    def feed(message_id,tag)
      feed = File.open("#{$fns_path}/etc/fnsfeed.conf")
      while line = feed.gets
        host,host_id,host_tag = line.split("!")
        p host
        p host_id 
        p host_tag
        if /#{tag}/ =~ host_tag
          $fns_queue.push("#{id}!#{message_id},#{tag}")
        end
      end
    end

    def send_res(code)
      @socket.puts(code)
    end

    def chk_hist?(message_id)
			history = DBM::open("#{$fns_path}/db/history",0666)
			
			if history.value?(message_id)
				puts "message_id<#{message_id}> already in history..."
				history.close
				return nil
			else
				puts "message_id<#{message_id}> not in history..."
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
      line = string.split("\n")
      while i < line.length
				unless line[i] == ""
          header_field,field_value = line[i].split(/\s*:\s*/)
					message[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end

      msg_line = 0
      while i < line.length
        break if line[i] == "."
		   	message["Body"] += "#{line[i]}\n"
		  	msg_line += 1
        i += 1 
      end

      message["line"] = msg_line
	  	return message
  	end
  end

end
