require 'nntpclient'

host = FriendNews::NNTPclient.new(11119)
host.connect("192.168.83.143")
host.trans_file("POST",file_path = "test",msg_id = nil,tag = nil)
