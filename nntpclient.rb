require 'socket'

module FriendNews

  class NNTPClient
    def initialize(port)
      @port = port
    end

    def connect(host)
      p host
      p @port
      @socket = TCPSocket.open(host,@port)
    end

    def disconnect
      @socket.close
    end

    def trans_file(cmd,file_path = nil,msg_id = nil,tag = nil)
      unless (msg_id && tag) || file_path
        puts "please write file path or msg_id"
        return -1
      end

      file_path = "#{$fns_path}/article/#{tag}/#{msg_id}" if (msg_id && tag)

      unless File.exist?(file_path)
        puts "Can't find file!!"
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
        puts "send msg"
        stat_code = send_msg(File.open(file_path))
        case self.stat_res(stat_code)
        when 1
          puts "Success code[#{stat_code.chomp}]"
        end
      end

      #return code
      return stat_code
    end

    def send_cmd(cmd_line)
      @socket.puts(cmd_line)
      while code = @socket.gets
        return code
      end
    end

    def send_msg(file)
      file.each{|line|
        p line
        @socket.puts(line)
      }
      while code = @socket.gets
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
