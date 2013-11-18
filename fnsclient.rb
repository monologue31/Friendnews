require 'socket'
require 'dbm'
require '/home/xiaokunyao/Friendnews/parsemsg.rb'

module FriendNews

  class FNSClient
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

end
