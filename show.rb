history = DBM::open("db/history",0666)
art = DBM::open("article/music/article_number",0666)

put "show history"
history.each_key{|k|
  p k
  p history[k]
}


