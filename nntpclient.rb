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

    def command(cmd,file_path = nil,msg_id = nil,tag = nil)
      puts "nntpclient:Starting command [#{cmd}]"
      
      unless File.exist?(file_path)
        puts "nntpclient:Can't find file with path[#{file_path}]"
        return -1
      end

      case cmd
      when /(?i)post/
        stat_code = self.post(file_path)
      when /(?i)ihave/
        stat_code = self.ihave(msg_id,tag)
      end

      #return code
      return stat_code
    end

    def send_cmd(cmd_line)
      @socket.puts(cmd_line)
      puts "nntpclient:Send command [#{cmd_line}]"
      while code = @socket.gets
        next unless code
        puts "nntpclient:Receive status code [#{code.chomp}]"
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

    def post(file_path)
        stat_code = self.send_cmd("POST")
        puts "nntpclient:Send message to server"
        return stat_code if stat_res(stat_code) != 1
        stat_code = send_msg(File.open(file_path))
        return stat_code
    end

    def ihave(msg_id,tag)
        stat_code = self.send_cmd("IHAVE #{msg_id}")
        puts "nntpclient:Send message to server"
        return stat_code if stat_res(stat_code) != 1
        file_path = "#{$fns_path}/article/#{tag}/#{msg_id}"
        stat_code = send_msg(File.open(file_path))
        return stat_code
    end

  end

end
