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
  attribute "email", "String"
  attribute "password", "String"
  attribute "security_key", "String"
  attribute "birth_date", "String"
  attribute "permission_level", "String"
end

class Loans < DatabaseHandler::Table
  table_name "loans"
  attribute "id", "Serial"
  attribute "user_id", "String"
  attribute "loan_id", "String"
  attribute "date_loaned", "String"
  attribute "item", "Integer"
  attribute "quantity", "Integer"
  attribute "item_id", "Integer"
end

class Stock_Inventory < DatabaseHandler::Table
  table_name "stock_inventory_items"
  attribute "id", "Serial"
  attribute "quantity", "Integer"
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

pp Inventory.all(:order => [:name, :asc])
#pp Inventory.first(:name => {:like => "mega"}, :quantity => "20")
#pp Categories.all({:name => {:like => "batt"}})