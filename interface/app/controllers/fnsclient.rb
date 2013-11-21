require 'socket'
require 'dbm'

module FriendNews

  class FNS_Client_Browser
    def connect(host,portno)
      begin
        @socket = TCPSocket.open(host,portno)
        puts "fnsclient:Connecting #{host} with port[#{portno}] successful code #{@socket.gets}"
				return true
      rescue => e
        puts "fnsclient:Connecting #{host} with port[#{portno}] error [#{e}]"
				return nil
      end
    end

    def disconnect
      @socket.close
    end

    def request(cmd_line)
      @socket.puts(cmd_line)
      puts "fnsclient:Send command <#{cmd_line}>"
      while code = @socket.gets
        next unless code
        puts "fnsclient:Receive status code <#{code.chomp}>"
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
=begin
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
=end
		def post_nntp(msg)
      stat_code = self.request("POST")
			return stat_code unless /340/ =~ stat_code
			stat_code = send_msg(@parsemsg.to_str(msg))
		end

		def post(msg)
			
		end

  end

end
