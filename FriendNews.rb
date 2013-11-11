require 'thread'
require './fnsserver.rb'

#Initialize globle parameter
$fns_queue = SizedQueue.new(100)
$fns_path = "/home/xiaokunyao/Friendnews"
$fns_host = ""

#Process.daemon
#Start Newfeeds
Thread.start do
  feeds   = FriendNews::FNSFeeds.new
  feeds.run
end

#Start Server
server  = FriendNews::FNSServer.new(119)
server.start

