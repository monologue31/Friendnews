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
