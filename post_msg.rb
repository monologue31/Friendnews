require './fnsserver.rb'

nntp = FriendNews::NNTP_Msg.new
nntp.port = 119
nntp.host = "localhost"
nntp.msg["From"] = "xiaokunyao"
nntp.msg["Subject"] = "Test post"
nntp.msg["Body"] = "this is the body"
nntp.msg["Tags"] = "all"
nntp.post
