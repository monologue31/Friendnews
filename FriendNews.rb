require 'thread'
require 'nntpserver'
require 'nntpfeeds'

#Initialize globle parameter
$fns_queue = SizedQueue.new(100)
$fns_path = "/usr/local/bin/Friendnews"
$fns_host = ""

#Start Server
server  = FriendNews::NNTPServer.new(11119)
server.start

#Start Newfeeds
feeds   = FriendNews::NNTRFeeds.new
feeds.run
