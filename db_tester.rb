require 'sqlite3'
require 'pp'

require 'data_mapper'
require 'dm-migrations'
require 'dm-types'
require 'dm-aggregates'
require 'dm-sqlite-adapter'
require 'benchmark'

require_relative 'DatabaseHandler'

DatabaseHandler.init(db_path: "database/database.sqlite")
require_relative 'database/models'

class Inventory_Item
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :barcode, String
  property :description, Text
  property :quantity, Integer
  property :category, Integer
end
#DataMapper.setup(:default, "sqlite:///#{Dir.pwd}/database/database.sqlite")

#p Loans.all(:user_id => 1, :order => [:id, :asc])
#pp Loans.execute("SELECT * FROM users INNER JOIN loans ON users.id = loans.user_id")

#p Categories.min(:id, :name => {:like => "tt"})
p Loans.count(:name => {:like => "tt"})


