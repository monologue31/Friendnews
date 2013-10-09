require 'thread'
require './nntpserver'
require './nntpfeeds'

#Initialize globle parameter
$fns_queue = SizedQueue.new(100)
$fns_path = "/usr/local/bin/Friendnews"
$fns_host = ""

#Start Newfeeds
Thread.start do
  feeds   = FriendNews::NNTPFeeds.new
  feeds.run
end

#Start Server
server  = FriendNews::NNTPServer.new(119)
server.start

