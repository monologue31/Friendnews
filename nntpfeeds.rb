require 'dbm'
require 'nntpclient'
require 'log'

module FriendNews

  class NNTPFeeds
   	def initialize()
  	end

	  def run
	  	#load feeds history
	  	Thread.start do
	  		loop do
	  			feeds_list = DBM::open("#{$fns_path}/db/feeds_list",0666)
		  		feeds_list.each_key{|host|
			  	  list = File.read("#{$fns_path}/feeds/#{host}")
            $fns_queue.push("#{host}!#{list}")
          }
				  feeds_list.close
				  sleep(3600) #sleep 1 hour
  			end
  		end

      
      #feeds news
  		loop do
        Thread.start do
          msg_list = $fns_queue.pop().split("!")
          puts msg_list
          host = msg_list[0] 
          msg_list.delete(host)
          client = FriendNews::NNTPClient.new(11119)
          client.connect(host)
          msg_list.each{|msg|
            msg_id,tag = msg.split(",")
            stat_code = client.tran_file("post",msg_id = msg_id,tag = tag)
            case code
            when 235
              self.del_hist(host,msg_id)
              self.append_log(host,msg_id)
            when 435||436||437
              puts "failed!message will post later!"
            end
          }
          end
      end
    end

    def del_hist(host,msg_id_del)
      messages = File.read("#{$fns_path}/feeds/#{host}").split("!")
      new_messages = ""
      messages.each{|message|
        msg_id,tag = message.split(",")
        unless msg_id = msg_id_del
          new_messages += "#{message}!"
        end
      }
      messages.close
      new_messages.slice!(-1)
      File.write("#{$fns_path}/feeds/#{host}",new_messages)
    end
  end

  def append_log(host,msg_id,tag)
    log = FriendNews::log.new("feeds",nil)
    log. append_log("Message-id[#{msg_id}] feed to #{host}----success")
    log.close
  end
end
