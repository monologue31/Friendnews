require 'socket'

module FriendNews

  class NNTPClient
    def initialize(port)
      @port = port
    end

    def connect(host)
      begin
        @socket = TCPSocket.open(host,@port)
        puts "nntpclient:Connecting #{host} with port[#{@port}] successful"
      rescue => e
        puts "nntpclient:Connecting #{host} with port[#{@port}] erro [#{e}]"
      end
    end

    def disconnect
      @socket.close
    end

    def command(cmd,param)
      puts "nntpclient:Sent command <#{cmd}>"
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
      @socket.puts(".")
      while code = @socket.gets
        next unless code
        return code
      end
    end

    def text_res
      res = ""
      while line = @socket.gets
        break if line == ".\n"
        res += line
      end
      return res
    end

    def ihave(msg_id)
      stat_code = self.request("IHAVE #{msg_id}")
      puts "nntpclient:Send message to server"
      return stat_code unless /355/ =~ stat_code
      history = DBM::open("#{$fns_path}/db/history",0666)
      tag = history[msg_id][7]
      artnum = history[msg_id][0]
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
