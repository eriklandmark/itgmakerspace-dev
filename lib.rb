class String
  def is_i?
    /\A[-+]?\d+\z/ === self
  end
end

def get_month_num_from_name(month:)
  case month
    when 'January'
      return 1
    when 'February'
      return 2
    when 'March'
      return 3
    when 'April'
      return 4
    when 'May'
      return 5
    when 'June'
      return 6
    when 'July'
      return 7
    when 'August'
      return 8
    when 'September'
      return 9
    when 'October'
      return 10
    when 'November'
      return 11
    when 'December'
      return 12
    else
      return 1
  end
end

def get_categories
  categories = []
  Categories.all(:order => [:name, :asc]).each do |category|
    if category.id != 0
      categories << {:category_id => category.id, :category_name => category.name}
    end
  end
  return categories
end

def get_inventory_names
  categories = []
  Categories.all.each do |category|
    categories << category.name
  end
  inventory_item_names = []
  Inventory.all(:order => [:name, :asc]).each do |item|
    inventory_item_names << [item.name, categories[item.category]]
  end
  inventory_item_names
end

def update_inventory_items
  all_loans = Loans.all(:status => Loans::ACTIVE){{:include => "items"}}
  if all_loans.length >= 1
    all_loans.each do |loan|
      loan.items.each do |item|
        inv_item = Inventory.first(:id => item.item_id)
        unless inv_item.update(:quantity => (inv_item.stock_quantity - item.quantity))
          puts "Error in updating inventory!! Item_id = #{item.item_id}, Loan_id = #{loan.id}"
        end
      end
    end
  else
    Inventory.all.each do |item|
      item.update(:quantity => item.stock_quantity)
    end
  end
end

def delete_inventory_item(item_id:, quantity:)
  item = Inventory.first(:id => item_id)
  if item != nil
    return item.update(:quantity => (item.quantity.to_i - quantity.to_i))
  else
    return false
  end
end

def add_inventory_item(item_id:, quantity:)
  item = Inventory.first(:id => item_id)
  if item != nil
    return item.update(:quantity => (item.quantity.to_i + quantity.to_i))
  else
    return false
  end
end

def log(msg)
  puts '[LOG] ' + msg.to_s
end