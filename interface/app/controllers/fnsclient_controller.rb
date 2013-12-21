class FnsclientController < ApplicationController
	layout "friendnews"
  def post
		if request.post?
			msg["From"] = params["from"]
			msg["Subject"] = params["subject"]
			msg["Newsgroups"] = params["tag"]
			msg["Body"] = params["body"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			@result = mgt.post(msg,"browser")
		else
		end
  end

  def control
		if request.post?
			msg["From"] = params["from"]
			msg["Subject"] = params["subject"]
			msg["Newsgroups"] = params["tag"]
			msg["Control"] = parms["control"]
			msg["Body"] = params["body"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			@result = mgt.post(msg,"browser")
		else
		end
  end

end
