require 'fileutils'

db = DBM.open(ARGV[0],0666)

db.each do |d|
  p d
end

