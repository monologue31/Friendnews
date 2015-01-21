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
      if params["acttype"] == "del"
        p "111111111111111111111"
			  tag_name = params["tag_name"]
			  url = "druby://localhost:11118"
			  mgt = DRbObject.new_with_uri(url)
			  mgt.rm_tag(tag_name)
      else
			  tag_name = params["tag_name"]
			  url = "druby://localhost:11118"
			  mgt = DRbObject.new_with_uri(url)
			  mgt.add_tag(tag_name)
      end
    else
    end
    @tags = Hash.new
		tagsdbm = DBM::open("#{File.expand_path('../')}/db/active",0666)
    tagsdbm.each do |t,p|
      @tags[t] = p.split(",")
    end
    tagsdbm.close
  end

  def mapping
		hostsdbm = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
    @rule = Hash.new {|h,k| h[k] = {}}
    count = 1
    hostsdbm.each_key do |h|
		  itagruledbm = DBM::open("#{File.expand_path('../')}/etc/rule/#{h}_trule_include",0666)
      itagruledbm.each do |k,r|
        @rule[count]["host"] = h
        @rule[count]["key_word"] = k
        @rule[count]["type"] = "tag include"
        @rule[count]["result"] = r
        count += 1
      end
      itagruledbm.close

		  etagruledbm = DBM::open("#{File.expand_path('../')}/etc/rule/#{h}_trule_equal",0666)
      etagruledbm.each do |k,r|
        @rule[count]["host"] = h
        @rule[count]["key_word"] = k
        @rule[count]["type"] = "tag equal"
        @rule[count]["result"] = r
        count += 1
      end
      etagruledbm.close

    end
    hostsdbm.close

    headers = ["From","Distribution","Subject"]
    headers.each do |h|
		  headerruledbm = DBM::open("#{File.expand_path('../')}/etc/rule/#{h}_rule",0666)
      headerruledbm.each do |k,r|
        @rule[count]["host"] = h
        @rule[count]["key_word"] = k
        @rule[count]["type"] = "header include"
        @rule[count]["result"] = r
        count += 1
      end
    end
    p @rule
  end

  def cmsg_list
		clistdbm = DBM::open("#{File.expand_path('../')}/db/cmsglist",0666) 
    if request.post?
  		url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
      clistdbm.each_key do |m|
        if params[m] == "1"
			    msg = mgt.article(params[m])
  		    @result = mgt.apply_cmsg(msg,"localhost")
        end
      end
    end
    @clist = Hash.new
    clistdbm.each do |k,v|
      @clist[k] = v
    end
    clistdbm.close
  end

  def hosts
		if request.post?
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.rm_host(params["host_domain"])
    else
    end
		hostsdbm = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		key_pool = DBM::open("#{File.expand_path('../')}/db/key_pool",0666)
    perm = DBM::open("#{File.expand_path('../')}/db/perm",0666)
    @hosts = Hash.new {|h,k| h[k] = {}}
    hostsdbm.each do |d,h|
      @hosts[h]["host_domain"] = d
			if key_pool.has_key?(d)
				@hosts[h]["key"] = 1
			else
				@hosts[h]["key"] = 0
			end
      @hosts[h]["control"] = perm[d]
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
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_host(params["host_domain"],params["host_name"],params["feed"],params["control"])
		else
		end
	end

	def add_tmapping
		if request.post?
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_tmapping(params["host_domain"],params["type"],params["key_word"],params["result"])
		else
		end
		@host_list = Hash.new
		host = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		host.each_key do |k|
			@host_list[k] = host[k]
		end
		host.close

		@tag_list = Hash.new
		tags = DBM::open("#{File.expand_path('../')}/db/active",0666)
		tags.each_key do |k|
			@tag_list[k] = tags[k]
		end
		tags.close
	end

	def add_hmapping
		if request.post?
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_hmapping(params["header"],params["key_word"],params["result"])
		else
		end
	end

	def add_tmapping
		if request.post?
			url = "druby://localhost:11118"
			mgt = DRbObject.new_with_uri(url)
			mgt.add_tmapping(params["host_domain"],params["type"],params["key_word"],params["result"])
		else
		end
		@host_list = Hash.new
		host = DBM::open("#{File.expand_path('../')}/db/hosts",0666)
		host.each_key do |k|
			@host_list[k] = host[k]
		end
		host.close

		@tag_list = Hash.new
		tags = DBM::open("#{File.expand_path('../')}/db/active",0666)
		tags.each_key do |k|
			@tag_list[k] = tags[k]
		end
		tags.close
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
    fnsconf = DBM::open("#{File.expand_path('../')}/etc/fns_conf",0666)
    if request.post?
      msg = Hash.new
  		msg["From"] = fnsconf["from"] 
  		msg["Subject"] = "New memberlist creat by #{fnsconf["host"]}"
  		msg["Tags"] = "control"
      msg["Control"] = "newml #{params["ml_name"]}" 
  		msg["User-Agent"] = request.env["HTTP_USER_AGENT"] + " fnsmgt"
      msg["Distribution"] = params["ml_name"]
      msg["Body"] = ""
      hostsdbm.each do |d,n|
        next if d == fnsconf["domain"]
        if params[n] == "1"
          msg["Body"] += d + "\t" + params["#{n}perm"] + "\r\n"
        end
      end
      msg["Body"] += fnsconf["domain"] + "\ta\r\n"
  		url = "druby://localhost:11118"
  		mgt = DRbObject.new_with_uri(url)
  		@result = mgt.post(msg)
    end
    @hosts = Hash.new
    hostsdbm.each do |d,n|
      next if d == fnsconf["domain"]
      @hosts[d] = n
    end
    hostsdbm.close
    fnsconf.close
  end

  def update_ml
    if request.post?
      if params["mlaction"] == "add"
      end
      mldbm = DBM::open("#{File.expand_path('../')}/etc/memberlist/#{params["ml_name"]}",0666)
      @ml = Hash.new
      mldbm.each do |h,p|
        if p == "a"
          @ml[h] = "administrator"
        elsif p == "r"
          @ml[h] = "read"
        elsif p == "w"
          @ml[h] = "write"
        end
      end
      mldbm.close
    end
  end

  def post
		if request.post?
      msg = Hash.new
			msg["From"] = params["from"]
			msg["Subject"] = params["subject"]
			msg["Tags"] = params["tag"]
      msg["Control"] = params["cmsgtype"] + "\s" + params["cmsgparam"] if params["cmsgtype"] != ""
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
