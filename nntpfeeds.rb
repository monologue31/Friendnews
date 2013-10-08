require 'dbm'
require './nntpserver'

module FriendNews

  class NNTPFeeds < NNTPServer
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
            list = Arrary.new
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
                unless hosts.include("!#{t}") && (hosts.include("!*") && !hosts.include("t"))
                  self.append_feedhist(msg["Message-ID"],l,nil)
                  @feedlist.push(l,msg["Message-ID"])
                end
              end
            end
          end
        end

        #thread feed message
        Thread.start do
          loop do
            host_id,msg_id = @feedlist.pop
            self.feed_msg(host_id,msg_id.split(","))
          end
        end
      rescue => e
        puts "error"
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
        feedhist.each_key do |m|
          msg_id += "#{m}," if (feedhist[m] == "436" || feedhist[m] == nil)
        end
        msg_id = msg_id.chop
        p msg_id
        @feedlist.push(k,msg_id)
        feedhist.close
      end
    end

    def feed_msg(host_id,msg_id)
      client = FriendNews::NNTPClient.new(119)
      host_ip = DBM::open("#{$fns_path}/db/hosts",0066)
      client.connect(host_ip[host_id])
      msg_id.each do |m|
        stat_code = client.command(ihave,m)
        self.append_feedhist(m,host,stat_code)
      end
      client.disconnect
      return
    end
    
  end

end
