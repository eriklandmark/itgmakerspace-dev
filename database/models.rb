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

  def self.get_inventory(params:)
    category_limit = Category.max(:id)
    order_of = nil
    order_dir = ''
    db_inventory = nil
    category = '0'

    if params.length == 0
      db_inventory = Inventory_Item.all(:order => [:name.asc])
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
            db_inventory = Inventory_Item.all(:name.like => '%' + search_term + '%', :order => [order_of.to_sym.asc])
          elsif order_dir == 'desc'
            db_inventory = Inventory_Item.all(:name.like => '%' + search_term + '%', :order => [order_of.to_sym.desc])
          else
            db_inventory = Inventory_Item.all(:name.like => '%' + search_term + '%', :order => [order_of.to_sym.asc])
          end
        else
          db_inventory = Inventory_Item.all(:name.like => '%' + search_term + '%')
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
                db_inventory = Inventory_Item.all(:order => [order_of.to_sym.asc])
              elsif order_dir == 'desc'
                db_inventory = Inventory_Item.all(:order => [order_of.to_sym.desc])
              else
                db_inventory = Inventory_Item.all(:order => [order_of.to_sym.asc])
              end
            else
              db_inventory = Inventory_Item.all(:order => [:name.asc])
            end
          else
            if order_of != nil
              if order_dir == 'asc'
                db_inventory = Inventory_Item.all(:category => params[:category], :order => [order_of.to_sym.asc])
              elsif order_dir == 'desc'
                db_inventory = Inventory_Item.all(:category => params[:category], :order => [order_of.to_sym.desc])
              else
                db_inventory = Inventory_Item.all(:category => params[:category], :order => [order_of.to_sym.asc])
              end
            else
              db_inventory = Inventory_Item.all(:category => params[:category])
            end
          end
        else
          if order_of != nil
            if order_dir == 'asc'
              db_inventory = Inventory_Item.all(:order => [order_of.to_sym.asc])
            elsif order_dir == 'desc'
              db_inventory = Inventory_Item.all(:order => [order_of.to_sym.desc])
            else
              db_inventory = Inventory_Item.all(:order => [order_of.to_sym.asc])
            end
          else
            db_inventory = Inventory_Item.all(:order => [:name.asc])
          end
        end
      end
    end

    db_inventory
  end
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
  property :permission_level, Integer, :default => 1
end