require './configure.rb'

conf = FriendNews::FNSConf.new()
conf.mkdir
conf.set_header
conf.clear_hist
conf.clear_tag

