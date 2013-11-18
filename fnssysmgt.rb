require "fileutils"
module FriendNews

	class FNS_sys_mgt
		def initialize(path)
			@fns_path = path
		end
    def add_host(host_name,host_domain)
      host = DBM::open("#{@fns_path}/db/hosts",0666)
      host[host_name] = host_domain
      msg = "create host <#{host_name}> ok,social router ip <#{host_ip}>"
			return msg
    end

		def rm_host(host_name)
      host = DBM::open("#{@fns_path}/db/hosts",0666)
			host.delete(host_name)
		end

    def add_feedrule(host_name,rule)
      host = DBM::open("#{@fns_path}/db/hosts",0666)
      if host.has_key?(host_name)
        fnsfeed = DBM::open("#{@fns_path}/etc/fnsfeed",0066)
        fnsfeed[host_name] = rule
        msg = "host <#{host_name}> add feedrule ok"
      else
        msg "do not find host <#{host_name}>"
      end
			return msg

		def rm_feedrule(host_name)
    	fnsfeed = DBM::open("#{@fns_path}/etc/fnsfeed",0066)
			fnsfeed.delete(hostname)
		end

    def add_mapping(rule,tag)
      tag_rule = DBM::open("#{@fns_path}/etc/tag_rule",0666)
      tag_rule[rule] = tag
      msg = "rule <#{rule}> to <#{tag}>"
			return msg
    end

		def rm_mapping(rule)
      tag_rule = DBM::open("#{@fns_path}/etc/tag_rule",0666)
			tag_rule.delete(rule)
		end

		def add_filter()
		end

		def rm_filter()
		end

		def set_expire()
		end

		def set_enviroments()
		end

		def add_key(host_domain,key)
			key_pool = DBM.open("#{@fns_path}/db/key_pool")
			key_pool[hots_domain] = key
		end

		def rm_key(host_domain)
			key_pool = DBM.open("#{@fns_path}/db/key_pool")
			key_pool.delete(host_domain)
		end

		def sys_init()
      FileUtils.mkpath("log")
      FileUtils.mkpath("tmp")
      FileUtils.mkpath("etc")
      FileUtils.mkpath("db/tags")
      FileUtils.mkpath("db/feedhist")
      FileUtils.mkpath("article/control")

      #clear message history
      history = DBM::open("#{@fns_path}db/history",0666)
      history.clear
      #clear feed histroy

			#clear tag
      fnstag = DBM::open("#{@fns_path}db/active",0666)
      fnstag.clear
      fnstag["all"] = "1,0,y,0"
      fnstag["control"] = "1,0,y,0"
      fnstag["junk"] = "1,0,y,0"
		end
	end

end

if ARGV.length < 1
  puts "useage:fnssysmgt.rb [command]"
else
   conf = FriendNews::FNSConf.new()
   command = ARGV[0]
   case command
   when "mkdir"
     conf.mkdir
   when "clear_hist"
     conf.clear_hist
   when "clear_tag"
     conf.clear_tag
   when "create_host"
     if ARGV.length < 3
       puts"ussage:configure.rb create_host [host_name] [host_ip]"
     else
       conf.create_host(ARGV[1],ARGV[2])
     end
   when "create_feedrule"
     if ARGV.length < 3
       puts"ussage:configure.rb create_feedrule [host_name] [rule]"
     else
       conf.create_feedrule(ARGV[1],ARGV[2])
     end
   when "tag_mapping"
     if ARGV.length < 3
       puts"ussage:configure.rb create_feedrule [rule] [tagname]"
     else
       conf.tag_mapping(ARGV[1],ARGV[2])
     end
   when "-h"
   else
      puts "use command -h to get help"
   end
end
