require 'date'

module FriendNews 

class Log
	def initialize(log_type,option_path)
		@log_type = log_type
    @option_path = option_path
	end

	def append_log(str)
		@log_name.puts("#{Time.now.to_s}:#{str}")
	end

	def show_log
	end

	def start
    unless File.exist?("#{$fns_path}/log/#{@log_type}/#{@option_path}#{Time.now.strftime("%Y%m%d")}")
			@log_name = File.open("#{$fns_path}/log/#{@log_type}/#{@option_path}#{Time.now.strftime("%Y%m%d")}"),"w")
		else
			@log_name = File.open("#{$fns_path}/log/#{@log_type}/#{@option_path}#{Time.now.strftime("%Y%m%d")}"),"a")
		end
	end
end

end
