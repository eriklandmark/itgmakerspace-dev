
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