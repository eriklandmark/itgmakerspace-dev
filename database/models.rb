class Categories < DatabaseHandler::Table
  table_name "categories"
  attribute "id", "Serial"
  attribute "name", "String"
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

  belongs_to :loan_items, self, :loan_id
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

  belongs_to :loans, Loans, :user_id
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