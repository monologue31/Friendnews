require 'nntpclient'

host = FriendNews::NNTPClient.new(11119)
host.connect("192.168.83.144")
host.trans_file("POST",file_path = "test",msg_id = nil,tag = nil)
