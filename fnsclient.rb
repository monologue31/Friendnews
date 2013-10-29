require 'socket'

module FriendNews

  class FNSClient
    def initialize(port)
      @port = port
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

    def send_msg(file)
      file.each{|line|
        @socket.puts(line)
      }
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
      puts "nntpclient:Send message to server"
      return stat_code unless /335/ =~ stat_code
      history = DBM::open("#{$fns_path}/db/history",0666)
      tag = history[msg_id].split("!")[7]
      artnum = history[msg_id].split("!")[0]
			p tag,artnum
      if tag == "control"
        path = "#{$fns_path}/article/control/#{artnum}"
      else
        path = "#{$fns_path}/article/#{artnum}"
      end
      stat_code = send_msg(File.open(path))
      return stat_code
    end

  end

end
