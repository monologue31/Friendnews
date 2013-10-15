require "fileutils"
require "dbm"

module FriendNews
  
  class FNSConf
    def initialize()
      @fns_path = ""
    end

    def set_header
      headers = DBM::open("#{@fns_path}db/headers",0666)
      headers.clear
      headers["1"] = "Date"
      headers["2"] = "From"
      headers["3"] = "Message-ID"
      headers["4"] = "Subject"
      headers["5"] = "Newsgroups"
      headers["6"] = "Path"
      headers["7"] = "Expires"
      headers["8"] = "Organization"
      headers["9"] = "Reply-To"
      headers["10"] = "Lines"
      headers["11"] = "Signature"
      headers["12"] = "Followup-To"
      headers["13"] = "References"
      headers["14"] = "Keywords"
      headers["15"] = "Summary"
      headers["16"] = "Distribution"
      headers["17"] = "User-Agent"
      headers["18"] = "MIME-Version"
      headers["19"] = "Content-Type"
      headers["20"] = "Content-Transfer-Encoding"
      headers["21"] = "Control"
      headers["22"] = "Xref"
      headers["23"] = "Msg-Sign"
      headers["24"] = "Body"
      puts "set header ok"
    end

    def mkdir
      FileUtils.mkpath("log")
      FileUtils.mkpath("tmp")
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
  end

end

if ARGV.length < 1
  puts "useage:configure.rb [command]"
else
   conf = FriendNews::FNSConf.new()
   command = ARGV[0]
   case command
   when "set_header"
     conf.set_header
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
       conf.feedrule(ARGV[1],ARGV[2])
     end
   when "-h"
     puts << EOS
     set_hearder
     mkdir
     clear_hist
     clear_tag
     create_host
     cereate_feedrule
     EOS
   else
      puts "use command -h to get help"
   end
end
