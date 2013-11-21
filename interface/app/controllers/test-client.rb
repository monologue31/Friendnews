require 'drb/drb'

def drbtest(argv)
	url = "druby://localhost:11118"
	t1 = DRbObject.new_with_uri(url)
	t1.rm_filter()
end

