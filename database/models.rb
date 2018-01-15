class Category
  include DataMapper::Resource

  property :id, Serial
  property :name, String
end

class Inventory_Item
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :barcode, String
  property :description, Text
  property :quantity, Integer
  property :category, Integer
end

class Loan
  include DataMapper::Resource

  property :id, Serial
  property :user_id, Integer
  property :loan_id, Integer
  property :date_loaned, String
  property :item_id, Integer
  property :item, String
  property :quantity, Integer
end

class Stock_Inventory_Item
  include DataMapper::Resource

  property :id, Serial
  property :quantity, Integer
end

class User
  include DataMapper::Resource

  property :id, Serial
  property :name, Text, :required => true, :lazy => false
  property :birth_date, String, :required => true
  property :email, String, :required => true
  property :password, BCryptHash, :required => true
  property :security_key, String
end