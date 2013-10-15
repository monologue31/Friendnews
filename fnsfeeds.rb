require 'dbm'
require './fnspserver'
require './fnsclient'

module FriendNews

  class FNSFeeds
    def initialize()
      @fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0666)
      @feedlist = Queue.new
  	end

	  def run
      begin
        self.load_feedlist
        #thread load feedlist
	  	  Thread.start do
	  	  	loop do
            sleep($feed_time)
            self.load_feedlist
  		  	end
  		  end

        #thread 
        Thread.start do
          loop do
            artnum,tags = $fns_queue.pop().split(",")
            if tags == "control"
              path = "#{$fns_path}/article/control"
            else
              path = "#{$fns_path}/article"
            end
            msg = self.to_hash(File.read("#{path}/#{artnum}"))
						puts "nntpfeeds:recevie messgae #{msg["Message-ID"]}"
						list = Array.new
						list.clear	
            if msg.has_key?("Distribution")
              msg["Distribuliton"].split(",").each do |d|
                DBM::opn("#{$fns_path}/etc/memberlist/#{d}",0666).each_key do |h|
                  unless list.include(h)
                    list << h
                  end
                end
              end
            else
              @fnsfeed.each_key do |h|
                list << h
              end
            end
            tag = tags.split(",")
            list.each do |l|
              hosts = @fnsfeed[l].split(",")
              tag.each do |t|
                if !hosts.include?("!#{t}") || (hosts.include?("!*") && !hosts.include?("t"))
                  self.append_feedhist(msg["Message-ID"],l,nil)
                  @feedlist.push("#{l},#{msg["Message-ID"]}")
                end
              end
            end
          end
        end

        #thread feed message
        Thread.start do
          loop do
            host_id,msg_id = @feedlist.pop.split(",")
						puts "nntpfeeds:feed message #{msg_id} to #{host_id}"
            self.feed_msg(host_id,msg_id.split(","))
          end
        end
      rescue => e
        puts "nntpfeeds error"
        puts e
      end
    end
    
    def append_feedhist(msg_id,host,stat_code)
      feedhist = DBM::open("#{$fns_path}/db/feedhist/#{host}")
      feedhist[host] = stat_code
      feedhist.close
    end

    def del_feedhist(msg_id,host)
      feedhist = DBM::open("#{$fns_path}/db/feedhist/#{host}")
      feedhist.delete(msg_id)
      feedhist.close
    end

    def load_feedlist
      @fnsfeed.each_key do |k|
        feedhist = DBM::open("#{$fns_path}/db/feedhist/#{k}")
        msg_id = ""
				cnt = 0
        feedhist.each_key do |m|
        	if (feedhist[m] == "436" || feedhist[m] == nil)
						msg_id += "#{m},"
						cnt += 1
					end
        end
        msg_id = msg_id.chop
        @feedlist.push("#{k},#{msg_id}") if cnt > 0
        feedhist.close
			end
    end

    def feed_msg(host_id,msg_id)
      client = FriendNews::FNSClient.new(119)
      host_ip = DBM::open("#{$fns_path}/db/hosts",0066)
      if client.connect(host_ip[host_id])
      	msg_id.each do |m|
      	  stat_code = client.command(ihave,m)
					puts "nntpfeeds:feed message #{m} status code #{stat_code}"
      	  self.append_feedhist(m,host,stat_code)
      	end
      	client.disconnect
			else
				puts "nntpfeeds:can't connet to host #{host_id}"
      	msg_id.each do |m|
      	  self.append_feedhist(m,host,"436")
      	end
			end
    end
    
    #Covert string to hash table
  	def to_hash(str)
      i = 0
      msg = Hash.new
      msg["Body"] = ""
      line = str.split("\r\n")
      while i < line.length
				unless line[i] == ""
          header_field,field_value = line[i].split(/\s*:\s*/,2)
					msg[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end
      msg_line = 0
      while i < line.length
		   	msg["Body"] += "#{line[i]}\r\n"
        break if line[i] == "."
		  	msg_line += 1
        i += 1 
      end
      msg["Lines"] = msg_line.to_s
	  	return msg
  	end
  end

end
