require "/home/xiaokunyao/Friendnews/fnsclient.rb"

class FnsclientController < ApplicationController
	layout "friendnews"
  def post
		if request.post? then
			fnsclient = FriendNews::FNSClient.new(119)
			msg = Hash.new
			if fnsclient.connect("localhost")
				msg["From"] = params["from"]
				msg["Subject"] = params["subject"]
				msg["Newsgroups"] = params["tag"]
				msg["Body"] = params["body"]
				p msg	
				@result = fnsclient.post(msg)
			else
				@result = "Connect to FNSserver Failed."
			end
		else
		end
  end

  def control
  end

	def show_msg
		if params["artnum"]
			art_num = params["artnum"]
			fnsclient = FriendNews::FNSClient.new(119)
			if fnsclient.connect("localhost")
				stat_code = fnsclient.request("GROUP junk")
				return unless /211/ =~ stat_code
				stat_code = fnsclient.request("Article #{art_num}")
				return unless /220/ =~ stat_code
				@result = fnsclient.text_res
			else
				@result = "Connect to FNSserver Failed."
			end
		end
	end
end
