require 'dbm'
require 'drb/drb'

class MainController < ApplicationController
	layout "friendnews"
  def index
  end

	def history
		history = DBM::open("#{File.expand_path('../')}/db/history",0666) 
    @hist = Hash.new
    history.each do |k,v|
      @hist[k] = v
    end
    history.close
	end

  def tags
		if request.post?
			tag_name = params["tag_name"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.rm_tag(tag_name)
    else
    end
    @tags = Hash.new
		tagsdbm = DBM::open("#{File.expand_path('../')}/db/active",0666)
    tagsdbm.each do |t,p|
      @tags[t] = p.split(",")
    end
    tagsdbm.close
  end

  def ctl_msg
  end

  def hosts
		if request.post?
			host_name = params["host_name"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.rm_host(host_name)
    else
    end
		hostsdbm = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		key_pool = DBM::open("#{File.expand_path('../')}/db/key_pool",0666)
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
		hosts = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		key_pool = DBM::open("#{File.expand_path('../')}/db/key_pool",0666)
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
		host = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		host.each_key do |k|
			@host_list[k] = host[k]
		end
		host.close
	end

  def memberlists
    listdbm = DBM::open("#{File.expand_path('../')}/etc/memberlist/list",0666)
    @list = Hash.new
    listdbm.each do |k,v|
      @list[k] = v
    end
    listdbm.close
  end

  def add_ml
		hostsdbm = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
    if request.post?
      fnsconf = DBM::open("#{File.expand_path('../')}/etc/fns_conf",0666)
      msg = Hash.new
  		msg["From"] = fnsconf["from"] 
  		msg["Subject"] = "New memberlist creat by #{fnsconf["host"]}"
  		msg["Tags"] = "control"
      msg["Control"] = "newml #{params["ml_name"]}" 
  		msg["User-Agent"] = request.env["HTTP_USER_AGENT"] + " fnsmgt"
      msg["Distribution"] = params["ml_name"]
      msg["Body"] = ""
      hostsdbm.each_key do |h|
        if params[h] == "1"
          msg["Body"] += hostsdbm[h] + "\t" + params["#{h}prem"] + "\r\n"
        end
      end
      msg["Body"] += hostsdbm["localhost"] + "\ta\r\n"
      fnsconf.close
  		url = "druby://localhost:11118"
      p msg
  		mgt = DRbObject.new_with_uri(url)
  		@result = mgt.post(msg)
    end
    @hosts = Hash.new
    hostsdbm.each do |k,v|
      next if k == "localhost"
      @hosts[k] = v
    end
    hostsdbm.close
  end

  def update_ml
  end

  def post
		if request.post?
      msg = Hash.new
			msg["From"] = params["from"]
			msg["Subject"] = params["subject"]
			msg["Tags"] = params["tag"]
      msg["Control"] = params["cmsgtype"] + "\s" + params["cmsgparam"]if params["cmsgtype"] != ""
			msg["User-Agent"] = request.env["HTTP_USER_AGENT"] + "\sfnsmgt"
      msg["Distribution"] = params["distributions"]
      msg["Body"] = params["body"]
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			@result = mgt.post(msg)
		else

		end
    @ml = Array.new
    list = DBM::open("#{File.expand_path('../')}/etc/memberlist/list",0666)
    list.each_key do |l|
      @ml << l
    end
  end

	def status
		statdbm = DBM::open("#{File.expand_path('../')}/etc/fns_conf",0666) 
    @stat = Hash.new
    statdbm.each do |k,v|
      @stat[k] = v
    end
    statdbm.close
	end
end
