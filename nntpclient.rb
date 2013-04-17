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

    def trans_file(cmd,file_path = nil,msg_id = nil,tag = nil)
      unless (msg_id && tag) || file_path
        puts "please write file path or msg_id"
        return -1
      end
  
      puts "nntpclient:Starting command [#{cmd}] with message_id[#{msg_id}] tag[#{tag}]"
      file_path = "#{$fns_path}/article/#{tag}/#{msg_id}" if (msg_id && tag)
      
      unless File.exist?(file_path)
        puts "nntpclient:Can't find file with path[#{file_path}]"
        return -1
      end

      case cmd
      when /(?i)post/
        cmd_line = "POST"
      when /(?i)ihave/
        cmd_line = "IHAVE #{msg_id}"
      end
      
      stat_code = self.send_cmd(cmd_line).chomp.to_i

      case self.stat_res(stat_code)
      when 1
        puts "nntpclient:Send message to server"
        stat_code = send_msg(File.open(file_path))
        case self.stat_res(stat_code)
        when 1
          puts "nntpclient:Transfer message successfule with code[#{stat_code.chomp}]"
        end
      end

      #return code
      return stat_code
    end

    def send_cmd(cmd_line)
      @socket.puts(cmd_line)
      puts "nntpclient:Send command [#{cmd_line}]"
      while code = @socket.gets
        puts "nntpclient:Receive status code [#{code.chomp}]"
        return code
      end
    end

    def send_msg(file)
      file.each{|line|
        @socket.puts(line)
      }
      while code = @socket.gets
        puts code
        next unless code
        return code
      end
    end

    def stat_res(code)
      case code[0]
      when 1
      when 2
      when 3
        case code[1]
        when 3
          return 1
        when 4
          return 1
        end
      when 4
      when 5
      else
        return 1
      end
    end

  end

end
