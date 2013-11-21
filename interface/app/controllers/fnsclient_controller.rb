require "./fnsclient.rb"

class FnsclientController < ApplicationController
	layout "friendnews"
  def post
		if request.post?
			fnsclient = FriendNews::FNSClient.new
			if true
				msg = Hash.new
				if fnsclient.connect("localhost",119)
					msg["From"] = params["from"]
					msg["Subject"] = params["subject"]
					msg["Newsgroups"] = params["tag"]
					msg["Body"] = params["body"]
					@result = fnsclient.post_nntp(msg)
				else
					@result = "Connect to FNSserver Failed."
				end
				fnsclient.diconnect
			else
				fnclient.post(msg)
			end
		else
		end
  end

  def control
		if request.post?
			fnsclient = FriendNews::FNSClient.new
			if true
				msg = Hash.new
				if fnsclient.connect("localhost",119)
					msg["From"] = params["from"]
					msg["Subject"] = params["subject"]
					msg["Newsgroups"] = params["tag"]
					msg["Control"] = params["Control"]
					msg["Body"] = params["body"]
					@result = fnsclient.post_nntp(msg)
				else
					@result = "Connect to FNSserver Failed."
				end
				fnsclient.diconnect
			else
				fnclient.post(msg)
			end
		else
		end
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

	def key_pool
		
	end

end
