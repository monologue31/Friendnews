require "fileutils"
require "dbm"
#make dir
FileUtils.mkpath("log")
FileUtils.mkpath("article/music")
FileUtils.mkpath("tmp/music")
FileUtils.mkpath("db")

#set header
header = DBM::open("db/header",0066)
header.clear
header["1"] = "Date"
header["2"] = "From"
header["3"] = "Message-id"
header["4"] = "Subject"
header["5"] = "Tag"
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
header["17"] = "Body"
