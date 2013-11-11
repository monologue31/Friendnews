require 'dbm'
class MainController < ApplicationController
	layout "friendnews"
  def index
  end

	def history
		@hist = DBM::open("/home/xiaokunyao/Friendnews/db/history",0666) 
	end

end
