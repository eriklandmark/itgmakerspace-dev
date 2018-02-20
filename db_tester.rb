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

DataMapper.setup(:default, "sqlite:///#{Dir.pwd}/database/database.sqlite")

puts Benchmark.measure {
  all = Inventory.all()
}

puts Benchmark.measure {
  all = Inventory_Item.all()
}


#p Categories.min(:id, :name => {:like => "tt"})
#p Categories.first(:name => {:like => "tt"},:order => [:name])

