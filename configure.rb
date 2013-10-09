require "fileutils"
require "dbm"

#make dir
FileUtils.mkpath("log")
FileUtils.mkpath("article/control")
FileUtils.mkpath("tmp")
FileUtils.mkpath("db/tags")
#set header
headers = DBM::open("db/headers",0666)
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

#clear history
history = DBM::open("db/history",0666)
history.clear
#creat tag
fnstag = DBM::open("db/active",0666)
fnstag.clear
fnstag["all"] = "0,0,y,0"
p fnstag["all"]
fnstag["control"] = "0,0,y,0"
p fnstag["control"]

#creat users
host_ip = DBM::open("#{$fns_path}/db/hosts",0066)
host_ip["xiao-face-vm-01"] = "192.168.83.145"
host_ip["xiao-face-vm-02"] = "192.168.83.146"

#creat feedlist
fnsfeed = DBM::open("#{$fns_path}/etc/fnsfeed",0666)
fnsfeed["xiao-face-vm-01"] = "*"
fnsfeed["xiao-fcae-vm-02"] = "*"
