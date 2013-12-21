require 'dbm'
require 'drb/drb'

class MainController < ApplicationController
	layout "friendnews"
  def index
  end

	def history
		@hist = DBM::open("/home/xiaokunyao/Friendnews/db/history",0666) 
	end

	def article
		if params["artnum"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			msg = mgt.article(params["artnum"])
			@result = msg.split("\r\n")
		end
	end

	def key_pool
		@key = Hash.new
		@key_str = Array.new
		hosts = DBM::open("/home/xiaokunyao/Friendnews/db/hosts",0666)
		key_pool = DBM::open("/home/xiaokunyao/Friendnews/db/key_pool",0666)
		hosts.each_key do |k|
			if key_pool.has_key?(k)
				@key[k] = "true"
			else
				@key[k] = "false"
			end
		end
		if params["host_name"]
			@key_str = key_pool[params["host_name"]].split("\n")
		end
		hosts.close
		key_pool.close
	end

	def add_localhost
		if request.post?
			host_name = "localhost" 
			host_domain = "#{params["host_name"]},#{params["host_domain"]}"
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_host(host_name,host_domain)
		else
		end
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
