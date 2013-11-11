require "fileutils"
require "dbm"

module FriendNews
  
  class FNSConf
    def initialize()
      @fns_path = ""
    end

    def mkdir
      FileUtils.mkpath("log")
      FileUtils.mkpath("tmp")
      FileUtils.mkpath("etc")
      FileUtils.mkpath("db/tags")
      FileUtils.mkpath("db/feedhist")
      FileUtils.mkpath("article/control")
    end

    def clear_hist
      #clear message history
      history = DBM::open("#{@fns_path}db/history",0666)
      history.clear
      #clear feed histroy
    end

    def clear_tag
      fnstag = DBM::open("#{@fns_path}db/active",0666)
      fnstag.clear
      fnstag["all"] = "1,0,y,0"
      fnstag["control"] = "1,0,y,0"
      fnstag["junk"] = "1,0,y,0"
    end
    
    def create_host(host_name,host_ip)
      host = DBM::open("#{@fns_path}db/hosts",0666)
      host[host_name] = host_ip
      puts "create host <#{host_name}> ok,social router ip <#{host_ip}>"
    end

    def create_feedrule(host_name,rule)
      host = DBM::open("#{@fns_path}db/hosts",0666)
      if host.has_key?(host_name)
        fnsfeed = DBM::open("#{@fns_path}etc/fnsfeed",0066)
        fnsfeed[host_name] = rule
        puts "host <#{host_name}> add feedrule ok"
      else
        puts "do not find host <#{host_name}>"
      end
    end
    
    def tag_mapping(rule,tag)
      tag_rule = DBM::open("#{@fns_path}etc/tag_rule",0666)
      tag_rule[rule] = tag
      puts "rule <#{rule}> to <#{tag}>"
    end
  end

end

if ARGV.length < 1
  puts "useage:configure.rb [command]"
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
