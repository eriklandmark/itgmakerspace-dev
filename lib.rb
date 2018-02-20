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
  item_ids = []
  loans = []
  all_loans = Loans.all
  if all_loans.length >= 1
    all_loans.each do |loan|
      unless item_ids.include?(loan.item_id)
        item_ids << loan.item_id
      end
    end

    item_ids.each do |id|
      q = 0
      c_loans = Loans.all(:item_id => id)
      c_loans.each do |loan|
        q = q + loan.quantity
      end
      loans << {:item_id => id, :quantity => q}
    end

    loans.each do |loan|
      item = Inventory.first(:id => loan[:item_id])
      item.update(:quantity => (item.stock_quantity - loan[:quantity]))
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

def error_msg(msg)
  puts '[Error] ' + msg.to_s
end

def log_error(msg:, e:, request:)
  log_dir = Dir.pwd + '/logs/'
  file_name = 'ErrorLog-' + Time.now.strftime('%Y%m%d_%H%M%S')
  file_content = "New error accured! #{request.ip} tried to access #{request.path} but internal error accured! \n
  Message: #{e.message} \n
  Backtrace: \n
  #{e.backtrace}"
end