require 'nntpclient'

host = FriendNews::NNTPClient.new(119)
host.connect("192.168.83.145")
host.trans_file("POST",file_path = "test",msg_id = nil,tag = nil)
