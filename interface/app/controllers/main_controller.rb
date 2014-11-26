require 'dbm'
require 'drb/drb'

class MainController < ApplicationController
	layout "friendnews"
  def index
  end

	def history
		history = DBM::open("/Users/monologue31/MyPG/Friendnews/db/history",0666) 
    @hist = Hash.new
    history.each do |k,v|
      @hist[k] = v
    end
    history.close
	end

  def hosts
		hostsdbm = DBM::open("/Users/monologue31/MyPG/Friendnews/db/hosts",0666)
		key_pool = DBM::open("/Users/monologue31/MyPG/Friendnews/db/key_pool",0666)
		if request.post?
      hostsdbm.delete(params["host_name"])
    else
    end
    @hosts = Hash.new {|h,k| h[k] = {}}
    hostsdbm.each do |h,d|
      @hosts[h]["host_domain"] = d
			if key_pool.has_key?(h)
				@hosts[h]["key"] = 1
			else
				@hosts[h]["key"] = 0
			end
    end
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
		hosts = DBM::open("/Users/monologue31/MyPG/Friendnews/db/hosts",0666)
		key_pool = DBM::open("/Users/monologue31/MyPG/Friendnews/db/key_pool",0666)
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
		host = DBM::open("/Users/monologue31/MyPG/Friendnews/db/hosts",0666)
		host.each_key do |k|
			@host_list[k] = host[k]
		end
		host.close
	end

  def memberlists
    listdbm = DBM::open("/Users/monologue31/MyPG/Friendnews/db/hosts",0666)
    @list = Hash.new
    listdbm.each do |k,v|
      @list[k] = v
    end
    listdbm.close
  end

  def add_ml
    if request.post?
      p params
    end
		hostsdbm = DBM::open("/Users/monologue31/MyPG/Friendnews/db/hosts",0666)
    @hosts = Hash.new
    hostsdbm.each do |k,v|
      @hosts[k] = v
    end
    hostsdbm.close
  end

  def update_ml
  end

	def status
		statdbm = DBM::open("/Users/monologue31/MyPG/Friendnews/etc/fns_conf",0666) 
    @stat = Hash.new
    statdbm.each do |k,v|
      @stat[k] = v
    end
    statdbm.close
	end
end
