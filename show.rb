require 'dbm'
history = DBM::open("db/history",0666)

p "show history"
p "---------------"
history.each_key{|k|
  p k
  p history[k]
}
p "---------------"

p "show tag"

fnstags = DBM::open("db/fnstags",0666)
p "---------------"
fnstags.each_key{|k|
  p k
  p fnstags[k]
}
p "---------------"

junk = DBM::open("db/junk",0666)
p "---------------"
junk.each_key{|k|
  p k
  p junk[k]
}
p "---------------"

all = DBM::open("db/all",0666)
p "---------------"
all.each_key{|k|
  p k
  p all[k]
}
p "---------------"

test = DBM::open("db/test",0666)
p "---------------"
test.each_key{|k|
  p k
  p test[k]
}
p "---------------"
