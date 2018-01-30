require 'sqlite3'
require 'pp'

require_relative 'DatabaseHandler'

DatabaseHandler.init(db_path: "database/database.sqlite")

class Categories < DatabaseHandler::Table
  table_name "categories"
  attribute "id", "Serial"
  attribute "name", "String"
end

class Users < DatabaseHandler::Table
  table_name "users"
  attribute "id", "Serial"
  attribute "name", "String"
end

class Inventory < DatabaseHandler::Table
  table_name "inventory_items"
  attribute "id", "Serial"
  attribute "name", "String"
  attribute "barcode", "String"
  attribute "description", "String"
  attribute "quantity", "Integer"
  attribute "category", "Integer"
end

pp Inventory.all(:category => "2", :name => {:like => "l"}, :order => [:name, :desc])
#pp Categories.all({:name => {:like => "batt"}})