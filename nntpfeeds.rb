require 'dbm'
require 'nntpserver'

module FriendNews

  class NNTPFeeds < NNTPServer
    def initialize()
      @fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0666)
      @fnsgroup = DBM::open("#{$fns_path}/etc/fnsgroup",0666)
  	end

	  def run
	  	#load feeds history
	  	Thread.start do
	  		loop do
	  			feed_list = DBM::open("#{$fns_path}/db/feeds_hist",0666)
		  		feed_list.each_key{|host|
			  	  list = File.read("#{$fns_path}/feeds/#{host}")
            $fns_queue.push("#{host}!#{list}")
          }
				  feeds_list.close
				  sleep(3600) #sleep 1 hour
  			end
  		end

      #feeds news
      loop do
        artnum,tag = $fns_queue.pop().split(",")
        if tag == "control"
          path = "#{$fns_path}/article/control"
        else
          path = "#{$fns_path}/article"
        end
        msg = self.to_hash(File.read("#{path}/#{artnum}"))
        puts "nntpfeeds:Transfer message #{msg["Message-ID"]}"
        if msg.has_key?("Distribution")
          hosts = @fnsgroup[msg["Distribuliton"]].split(",")
        else
          @fnsfeed.each_key do |h|
            hosts << u
          end
        end
        hosts.each do |h|
          feed_ip,feed_tags = @fnsfeed[u].split(",",2)
          if feed_tags != "*"
            feed_tags.each do |ft|
              if msg["Newsgroups"].include(ft)
                hosts.delete(u)
                break
              end
            end
          end
        end
        client = FriendNews::NNTPClient.new(119)
        hosts.each do |h|
          client.connect(host)
          stat_code = client.command(ihave,msg["Message-ID"])
          client.disconnect
        end
      end
    end
  end

end
