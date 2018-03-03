class Categories < DatabaseHandler::Table
  table_name "categories"
  attribute "id", "Integer", :not_null => true, :primary_key => true
  attribute "name", "VARCHAR(50)"

  init_table
end

class Loan_Items < DatabaseHandler::Table
  ACTIVE = 1
  INACTIVE = 0

  table_name "loan_items"

  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "loan_id", "Integer"
  attribute "status", "Integer"
  attribute "quantity", "Integer"
  attribute "item_id", "Integer"

  init_table
end

class Loans < DatabaseHandler::Table
  ACTIVE = 1
  INACTIVE = 0

  table_name "loans"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "user_id", "Integer"
  attribute "status", "Integer"
  attribute "date_loaned", "VARCHAR(30)"

  belongs_to :items, Loan_Items, :id, :loan_id

  init_table
end

class Users < DatabaseHandler::Table
  table_name "users"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "name", "VARCHAR(100)"
  attribute "email", "VARCHAR(100)"
  attribute "password", "VARCHAR(65)"
  attribute "security_key", "VARCHAR(100)"
  attribute "birth_date", "VARCHAR(30)"
  attribute "permission_level", "Integer"

  belongs_to :loans, Loans, :id, :user_id

  init_table
end

class Inventory < DatabaseHandler::Table
  table_name "inventory_items"
  attribute "id", "Integer", :primary_key => true, :auto_increment => true, :not_null => true
  attribute "name", "VARCHAR(50)"
  attribute "barcode", "VARCHAR(10)"
  attribute "description", "VARCHAR(16655)"
  attribute "quantity", "Integer"
  attribute "category", "Integer"
  attribute "stock_quantity", "Integer"

  init_table

  def self.get_inventory(params:)
    inventory_hash = {}

    if !params.nil? && params.length > 0
      if params[:search_term] != nil && params[:search_term] != ''
        inventory_hash[:name] = {:like => params[:search_term]}
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