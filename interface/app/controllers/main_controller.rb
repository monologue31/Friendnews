require 'dbm'
require 'drb/drb'

class MainController < ApplicationController
	layout "friendnews"
  def index
  end

	def history
		@hist = DBM::open("/home/xiaokunyao/Friendnews/db/history",0666) 
	end

	def key_pool
	end

	def add_host
		if request.post?
			host_name = params["host_name"]
			host_domain = params["host_domain"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_host(host_name,host_domain)
		else
		end
	end

	def upload_key
		if request.post?
			key = params["public_key"]
			host = params["host"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_key(host,key.read)
		else
		end
		@host_list = Hash.new
		host = DBM::open("/home/xiaokunyao/Friendnews/db/hosts",0666)
		host.each_key do |k|
			@host_list[k] = host[k]
		end
		host.close
	end

	def sys_stat
	end
end
