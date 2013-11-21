require 'dbm'

module FriendNews

	class ParseMsg
		def initialize 
			@headers = Hash.new	
      @headers["1"] = "Date"
      @headers["2"] = "From"
      @headers["3"] = "Message-ID"
      @headers["4"] = "Subject"
      @headers["5"] = "Tag"
      @headers["6"] = "Path"
      @headers["7"] = "Expires"
      @headers["8"] = "Organization"
      @headers["9"] = "Reply-To"
      @headers["10"] = "Lines"
      @headers["11"] = "Signature"
      @headers["12"] = "Followup-To"
      @headers["13"] = "References"
      @headers["14"] = "Keywords"
      @headers["15"] = "Summary"
      @headers["16"] = "Distribution"
      @headers["17"] = "User-Agent"
      @headers["18"] = "MIME-Version"
      @headers["19"] = "Content-Type"
      @headers["20"] = "Content-Transfer-Encoding"
      @headers["21"] = "Control"
      @headers["22"] = "Xref"
      @headers["23"] = "Msg-Sign"
      @headers["24"] = "Body"
		end

  	def to_str(msg_hash)
	  	msg = ""
  		i = 1
  		while i <= @headers.length
  			unless @headers[i.to_s] == "Body"
  				if msg_hash[@headers[i.to_s]]
  					msg += @headers[i.to_s] + ":\s" + msg_hash[@headers[i.to_s]] + "\r\n"
  				end
  			else
          msg += "\r\n"
  				msg += msg_hash[@headers[i.to_s]]
  			end
  			i += 1
  		end	
  		return msg
  	end

    #Covert string to hash table
  	def to_hash(str)
      i = 0
      msg = Hash.new
      msg["Body"] = ""
      line = str.split("\r\n")
      while i < line.length
				unless line[i] == ""
          header_field,field_value = line[i].split(/\s*:\s*/,2)
					msg[header_field] = field_value
          i += 1
				else
          i += 1
          break
				end
      end
      msg_line = 0
      while i < line.length
		   	msg["Body"] += "#{line[i]}\r\n"
        break if line[i] == "."
		  	msg_line += 1
        i += 1 
      end
      msg["Lines"] = msg_line.to_s
	  	return msg
  	end
	end

end
