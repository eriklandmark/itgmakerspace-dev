class Categories < DatabaseHandler::Table
  table_name "categories"
  attribute "id", "Integer", :not_null => true, :primary_key => true
  attribute "name", "VARCHAR(50)"

  init_table
end

class Test < DatabaseHandler::Table
  table_name "test"
  attribute "id", "Integer", :not_null => true, :primary_key => true
  attribute "name", "VARCHAR(50)"
  attribute "test", "Integer", :not_null => false, :default => nil

  init_table
end

class Loans < DatabaseHandler::Table
  table_name "loans"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "user_id", "String"
  attribute "loan_id", "String"
  attribute "date_loaned", "String"
  attribute "item", "Integer"
  attribute "quantity", "Integer"
  attribute "item_id", "Integer"

  init_table
end

class Users < DatabaseHandler::Table
  table_name "users"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "name", "String"
  attribute "email", "String"
  attribute "password", "String"
  attribute "security_key", "String"
  attribute "birth_date", "String"
  attribute "permission_level", "String"

  belongs_to :loans, Loans, :user_id

  init_table
end

class Inventory < DatabaseHandler::Table
  table_name "inventory_items"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "name", "String"
  attribute "barcode", "String"
  attribute "description", "String"
  attribute "quantity", "Integer"
  attribute "category", "Integer"
  attribute "stock_quantity", "Integer"

  init_table

  def self.get_inventory(params:)
    inventory_hash = {}

    if !params.nil? && params.length > 0
      if params[:search_term] != nil && params[:search_term] != ''
        inventory_hash[:name] = params[:search_term]
      end
      if params[:category] != nil && params[:category].to_i <= Categories.max(:id)
        inventory_hash[:category] = params[:category]
      end
      if params[:sort_after] != nil && (params[:sort_after] == "name_asc" || params[:sort_after] == "name_desc" || params[:sort_after] == "quantity_asc" || params[:sort_after] == "quantity_desc")
        order_type = params[:sort_after][0..params[:sort_after].index('_') - 1]
        order_dir = params[:sort_after][params[:sort_after].index('_') + 1..-1]
        inventory_hash[:order] = [order_type.to_sym, order_dir.to_sym]
      end
    end

    Inventory.all(inventory_hash)
  end
end