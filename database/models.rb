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

  def self.get_inventory(params:)
    category_limit = Categories.max(:id)
    order_of = nil
    order_dir = ''
    db_inventory = nil
    category = '0'

    if params.length == 0
      db_inventory = Inventory.all(:order => [:name, :asc])
    else
      if params[:search_term] != nil && params[:search_term] != ''
        search_term = params[:search_term]
        order_of = nil
        order_dir = ''
        if params[:sort_after] != nil
          if params[:sort_after] == 'name_asc'
            order_of = 'name'
            order_dir = 'asc'
          elsif params[:sort_after] == 'name_desc'
            order_of = 'name'
            order_dir = 'desc'
          elsif params[:sort_after] == 'quantity_asc'
            order_of = 'quantity'
            order_dir = 'asc'
          elsif params[:sort_after] == 'quantity_desc'
            order_of = 'quantity'
            order_dir = 'desc'
          else
            order_of = 'quantity'
            order_dir = 'desc'
          end
        end
        if order_of != nil
          if order_dir == 'asc'
            db_inventory = Inventory.all(:name => {:like => search_term}, :order => [order_of.to_sym, :asc])
          elsif order_dir == 'desc'
            db_inventory = Inventory.all(:name => {:like => search_term}, :order => [order_of.to_sym, :desc])
          else
            db_inventory = Inventory.all(:name => {:like => search_term}, :order => [order_of.to_sym, :asc])
          end
        else
          db_inventory = Inventory.all(:name => {:like => search_term})
        end
      else
        if params[:sort_after] != nil
          if params[:sort_after] == 'name_asc'
            order_of = 'name'
            order_dir = 'asc'
          elsif params[:sort_after] == 'name_desc'
            order_of = 'name'
            order_dir = 'desc'
          elsif params[:sort_after] == 'quantity_asc'
            order_of = 'quantity'
            order_dir = 'asc'
          elsif params[:sort_after] == 'quantity_desc'
            order_of = 'quantity'
            order_dir = 'desc'
          end
        end

        if params[:category] != nil && params[:category].is_i?
          if params[:category].to_i < 1 || params[:category].to_i > category_limit
            if order_of != nil
              if order_dir == 'asc'
                db_inventory = Inventory.all(:order => [order_of.to_sym, :asc])
              elsif order_dir == 'desc'
                db_inventory = Inventory.all(:order => [order_of.to_sym, :desc])
              else
                db_inventory = Inventory.all(:order => [order_of.to_sym, :asc])
              end
            else
              db_inventory = Inventory.all(:order => [:name, :asc])
            end
          else
            if order_of != nil
              if order_dir == 'asc'
                db_inventory = Inventory.all(:category => params[:category], :order => [order_of.to_sym, :asc])
              elsif order_dir == 'desc'
                db_inventory = Inventory.all(:category => params[:category], :order => [order_of.to_sym, :desc])
              else
                db_inventory = Inventory.all(:category => params[:category], :order => [order_of.to_sym, :asc])
              end
            else
              db_inventory = Inventory.all(:category => params[:category])
            end
          end
        else
          if order_of != nil
            if order_dir == 'asc'
              db_inventory = Inventory.all(:order => [order_of.to_sym, :asc])
            elsif order_dir == 'desc'
              db_inventory = Inventory.all(:order => [order_of.to_sym, :desc])
            else
              db_inventory = Inventory.all(:order => [order_of.to_sym, :asc])
            end
          else
            db_inventory = Inventory.all(:order => [:name, :asc])
          end
        end
      end
    end

    db_inventory
  end
end