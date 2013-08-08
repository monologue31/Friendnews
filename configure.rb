require "fileutils"
require "dbm"

#make dir
FileUtils.mkpath("log")
FileUtils.mkpath("article")
FileUtils.mkpath("tmp")
FileUtils.mkpath("db")

#set header
header = DBM::open("db/header",0666)
header.clear
header["1"] = "Date"
header["2"] = "From"
header["3"] = "Message-ID"
header["4"] = "Subject"
header["5"] = "Newsgroups"
header["6"] = "Path"
header["7"] = "Expires"
header["8"] = "Organization"
header["9"] = "Reply-To"
header["10"] = "Lines"
header["11"] = "Signature"
header["12"] = "Followup-To"
header["13"] = "References"
header["14"] = "Keywords"
header["15"] = "Summary"
header["16"] = "Distribution"
header["17"] = "User-Agent"
header["18"] = "MIME-Version"
header["19"] = "Content-Type"
header["20"] = "Content-Transfer-Encoding"
header["21"] = "Control"
header["22"] = "Xref"
header["23"] = "Msg-Sign"
header["24"] = "Body"

#clear history
history = DBM::open("db/history",0666)
history.clear
#creat tag
fnstag = DBM::open("db/fnstags",0666)
fnstag.clear
fnstag["all"] = "0,0,y,0"
p fnstag["all"]
fnstag["junk"] = "0,0,y,0"
p fnstag["junk"]
fnstag["control"] = "0,0,y,0"
p fnstag["control"]
#creat article
fnsarts = DBM::open("db/fnsarts")
fnsarts.clear

