class App < Sinatra::Base
  use Rack::MethodOverride
  helpers Sinatra::ContentFor

  if settings.production?
    use Rack::SslEnforcer, :redirect_to => 'https://itgmaker.space'
  end

  enable :sessions
  set :session_secret, 'itg-makerspace'
  set :show_exceptions, false
  set :default_charset, 'utf-8'
  set :method_override, true

  not_found do
    ErrorHandler.e_404(self, nil)
  end

  error do
    ErrorHandler.e_500(self, nil)
  end

  get '/' do
    dates = nil
    File.open('meeting_dates.json', 'r') do |file|
      dates = JSON.parse(file.read)
    end
    year, month, day = ''
    hour = '15'
    started = false

    dates['dates'].each do |date|
      if DateTime.new(date['year'].to_i, get_month_num_from_name(month: date['month']), date['day'].to_i, 15, 00, 00, '+1') > DateTime.now
        year = date['year']
        month = date['month']
        day = date['day']
        break
      elsif DateTime.now < DateTime.new(date['year'].to_i, get_month_num_from_name(month: date['month']), date['day'].to_i, 17, 00, 00, '+1')
        year = date['year']
        month = date['month']
        day = date['day']
        hour = '17'
        started = true
        break
      end
    end

    slim :index, :locals => {:day => day, :year => year, :month => month, :hour => hour, :started => started}
  end

  get '/login' do
    redirect '/session/new'
  end

  get '/session/new' do
    if session[:user_id].nil?
      slim :login
    else
      redirect "/users/#{session[:user_id]}"
    end
  end

  post '/session' do
    user = Users.first(:email => params['user_email'].downcase)
    if session[:user_id].nil?
      if user != nil
        if BCrypt::Password.new(user.password) == params['user_password']
          session[:user_full_name] = user.name
          session[:user_id] = user.id
          session[:permission_level] = user.permission_level

          redirect '/'
        else
          ErrorHandler.e_500(self, "Fel lösenord!")
        end
      else
        ErrorHandler.e_500(self, "Användaren finns tyvärr inte..")
      end
    else
      redirect "/users/#{session[:user_id]}"
    end
  end

  get '/users/new' do
    if session[:user_id].nil?
      slim :register
    else
      ErrorHandler.e_403(self, "Tyvärr! Du får inte tillgång till denna sida när du är inloggad.<br>Logga ut först för att få tillgång till denna sida.")
    end
  end

  post '/users/new' do
    uri = URI.parse("https://www.google.com/recaptcha/api/siteverify?response=#{params['g-recaptcha-response']}&secret=6LdrnTkUAAAAACJ0UTJYDXjV2oVl_DoQsfIVwXm1")
    success = false
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri
      response = http.request request
      success = JSON.parse(response.body)["success"]
    end

    if success && session[:user_id].nil?
      u = Users.first(:email => params['email'].downcase)
      if u == nil && params['password1'] == params['password2']
        new_user = {
            :email => params['email'].downcase,
            :password => BCrypt::Password.create(params['password1']),
            :name => params['fullname'],
            :birth_date => params['birth']
        }

        if Users.create(new_user)
          slim :login, :locals => {:login_msg => "#{params['fullname']} är nu registrerad! Logga in nedan."}
        else
          ErrorHandler.e_500(self, 'Ojdå.. Detta borde inte hända. Försök igen.')
        end
      else
        ErrorHandler.e_500(self, 'Dina lösenord stämde inte överens. Försök igen!')
      end
    else
      ErrorHandler.e_403(self, 'Ojdå.. Du blev stoppad av reCAPTCHA. När du vet att du inte är en robbot, försök igen!')
    end
  end

  delete '/session/delete' do
    session[:user_full_name] = nil
    session[:user_id] = nil
    session[:permission_level] = nil
    redirect '/'
  end

  get '/users/:user_id/edit' do
    if params[:user_id].to_i == session[:user_id] || (!session[:permission_level].nil? && session[:permission_level] >= 2)
      user = Users.first(:id => session[:user_id])
      if user != nil
        slim :change_password, :locals => {:user_id => params["user_id"]}
      else
        ErrorHandler.e_500(self, nil)
      end
    else
      ErrorHandler.e_403(self, nil)
    end
  end

  patch '/users/:user_id/edit' do
    if params[:user_id].to_i == session[:user_id] || (!session[:permission_level].nil? && session[:permission_level] >= 2)
      user = Users.first(:id => session[:user_id])
      if user != nil
        if BCrypt::Password.new(user.password) == params['user_password'] && params[:new_password_1] == params[:new_password_2]
          if user.update(:password => BCrypt::Password.create(params[:new_password_1]))
            session[:user_full_name] = nil
            session[:user_id] = nil
            session[:permission_level] = nil

            redirect '/session/new'
          end
        else
          ErrorHandler.e_500(self, "Lösenorden stämmer inte överense. Försök igen!")
        end
      end
    else
      ErrorHandler.e_403(self, nil)
    end
  end

  post '/api/user-authentication' do
    response = {:status => "false"}
    sec_key = SecureRandom.hex(20)
    if params['user_email'].nil?
      user = Users.first(:id => session[:user_id])
    else
      user = Users.first(:email => params['user_email'].downcase)
    end

    if user != nil
      if BCrypt::Password.new(user.password) == params['user_password'] && user.update(:security_key => response[:security_key])
        response[:user_id] = user.id
        response[:security_key] = sec_key
        response[:name] = user.name
        response[:email] = user.email
        response[:status] = 'true'
      else
        response[:status_msg] = "Fel användare och/eller lösenord. Försök igen."
      end
    else
      response[:status_msg] = "Fel användare och/eller lösenord. Försök igen."
    end
    response.to_json
  end

  post '/api/user-exists' do
    response = {:status => "true"}
    unless Users.first(:email => params['user_email'].downcase).nil?
      response[:status] = "false"
    end
    response.to_json
  end

  get '/users/:user_id/loans' do
    if !params["origin"].nil? && params["origin"] == "2"
      security_key = params['security_key']
      user_id = params['user_id']
      response = {:status => 'false', :status_msg => ''}
      user = Users.first(:id => user_id)
      if user != nil && user.security_key == security_key
        items = []
        Loans.all(:user_id => user_id, :status => Loans::ACTIVE, :order => [:id, :asc]) {{:include => "items"}}.each do |loan|
          loan.items.each do |item|
            if item.status == Loans::ACTIVE
              items << {:quantity => item.quantity, :item_id => item.item_id, :loan_id => loan.id, :date_loaned => loan.date_loaned, :item_name => Inventory.first(:id => item.item_id).name}
            end
          end
        end
        response[:status] = 'true'
        response[:items] = items
      end

      response.to_json
    elsif params["user_id"].to_i == session[:user_id] || (!session[:permission_level].nil? && session[:permission_level] >= 2)
      loans_items = []
      user_id = session[:user_id]
      user_loans = Loans.all(:user_id => user_id, :status => Loans::ACTIVE, :order => [:id, :asc]) {{:include => "items"}}
      total_of_user_loans = Loans.max(:id, :user_id => user_id)

      unless total_of_user_loans.nil? && user_loans.nil?
        total_of_user_loans.times do |id|
          items = []
          date = ''
          user_loans.each do |loan|
            loan.items.each do |item|
              if loan.id == (id + 1) && item.status == Loan_Items::ACTIVE
                date = loan.date_loaned
                items << {:item => Inventory.first(:id => item.item_id).name, :quantity => item.quantity, :item_id => item.item_id, :loan_id => loan.id}
              end
            end
          end
          if items.length > 0
            loans_items << {:date => date.sub('_', ' kl '), :items => items}
          end
        end
      end
      slim :my_loans, :locals => {:loans_items => loans_items}
    else
      ErrorHandler.e_403(self, nil)
    end
  end

  post '/users/:user_id/loans/new' do
    response = {:status => "true"}
    security_key = params['security_key']
    user_id = params['user_id']
    items = params['items']
    loan_id = Loans.max(:id)
    if loan_id == nil
      loan_id = 1
    else
      loan_id += 1
    end

    user = Users.first(:id => user_id)
    if user == nil
      response[:status] = "false"
      response[:status_msg] = "User doesn't exists!"
    end

    if user.security_key != security_key
      response[:status] = "false"
      response[:status_msg] = "Error with user verification try to logout and login again."
    end

    if response[:status] == "true"
      items = JSON.parse(items)
      date = Time.new.strftime('%Y-%m-%d_%H:%M:%S')
      if Loans.create({
                          :id => loan_id,
                          :date_loaned => date,
                          :status => Loans::ACTIVE,
                          :user_id => user_id
                      })
        items.each do |item|
          unless Loan_Items.create({
                                       :loan_id => loan_id,
                                       :item_id => item['item_id'],
                                       :quantity => item['quantity'],
                                       :status => Loans::ACTIVE
                                   })
            response[:status] = "false"
            response[:status_msg] = "Loan did not save!"
          end

          unless delete_inventory_item(item_id: item['item_id'], quantity: item['quantity'])
            response[:status] = "false"
            response[:status_msg] = "Couldn't update inventory!"
          end
        end
      end
    end

    response.to_json
  end

  post '/users/;user_id/loans/delete' do
    response = {:status => 'false'}
    origin = params['origin'].to_i
    user_id = params['user_id'].to_i
    if params['user_id'] == nil
      user_id = session[:user_id]
    end
    item_id = params['item_id'].to_i
    loan_id = params['loan_id'].to_i
    quantity = params['quantity'].to_i
    user = Users.first(:id => user_id)
    if user != nil
      proceed = false
      if origin == 2 && params['security_key'] != nil && user.security_key == params['security_key']
        proceed = true
      elsif origin == 1 && user_id != nil
        proceed = true
      end

      item = Loan_Items.first(:item_id => item_id, :loan_id => loan_id, :status => Loan_Items::ACTIVE)
      if item != nil && proceed
        if item.quantity > quantity
          if item.update(:quantity => (item.quantity - quantity))
            add_inventory_item(item_id: item_id, quantity: quantity)
            response[:status] = 'true'
          end
        else
          old_quantity = item.quantity
          if item.update({:status => Loan_Items::INACTIVE})
            add_inventory_item(item_id: item_id, quantity: old_quantity)
            response[:status] = 'true'
          end
        end
        if Loan_Items.count(:loan_id => loan_id, :status => Loan_Items::ACTIVE) <= 0
          if Loans.first(:id => loan_id).update(:status => Loans::INACTIVE)
            response[:status] = 'true'
          else
            response[:status] = 'false'
          end
        end
      end
    end

    response.to_json
  end

  post '/users/:user_id/loans/delete-all' do
    response = {:status => "true"}
    user_id = params['user_id'].to_i
    security_key = params['security_key']
    user = Users.first(:id => user_id)
    if user != nil
      if user.security_key == security_key
        Loans.all(:user_id => user_id){{:include => "items"}}.each do |loan|
          unless loan.update(:status => Loans::INACTIVE)
            response[:status] = "false"
            response[:status_msg] = "Error deleting loan. [Code: 5001]"
          end
          loan.items.each do |item|
            unless item.update(:status => Loans::INACTIVE)
              response[:status] = "false"
              response[:status_msg] = "Error deleting loan. [Code: 5002]"
            end
          end
        end
      end
    end
    response.to_json
  end

  get '/inventory' do
    inventory = []
    category = params[:category]
    search_term = params[:search_term]

    if search_term.nil?
      search_term = ""
    end
    if category.nil?
      category = "0"
    end

    db_inventory = Inventory.get_inventory(params: params)

    if db_inventory != nil && db_inventory.length > 0
      if !(search_term.length > 0 && db_inventory.length < 2)
        db_inventory.each do |item|
          item = {
              :id => item.id,
              :name => item.name,
              :barcode => item.barcode,
              :description => item.description.nil? || item.description == '' ? 'Description to be added' : item.description,
              :quantity => item.quantity,
              :category => item.category
          }

          inventory << item
        end

        slim :inventory, :locals => {:inventory => inventory, :category_name => Categories.first(:id => category).name, :search_term => search_term}
      else
        redirect "/inventory/#{db_inventory.first.id}"
      end
    else
      if search_term.length > 0
        slim :inventory, :locals => {:search_term => search_term, :inventory => db_inventory, :category_name => Categories.first(:id => category).name}
      else
        redirect '/inventory'
      end
    end
  end

  get '/inventory/new' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        return slim(:"add-inventory-item", :locals => {
            :item_id => "-1",
            :item_name => "",
            :item_barcode => "",
            :item_category => 0,
            :item_quantity => 1,
            :item_description => "",
            :action => "new"
        })
      end
    end

    ErrorHandler.e_403(self, nil)
  end

  post '/inventory/new' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        id = Inventory.max(:id).to_i + 1

        if Inventory.create({
                                :id => id,
                                :name => params["item-name"],
                                :barcode => params["item-barcode"],
                                :quantity => params["item-quantity"].to_i,
                                :description => params["item-description"],
                                :category => params["item-category"],
                                :stock_quantity => params["item-quantity"].to_i
                            })
          unless params[:"item-picture"].nil?
            if File.exists?("./public/product_images/product_#{id}.jpg")
              File.delete("./public/product_images/product_#{id}.jpg")
            end

            File.open("./public/product_images/product_#{id}.jpg", "w") do |file|
              file.write(params['item-picture'][:tempfile].read)
            end
          end

          redirect '/inventory'
        else
          ErrorHandler.e_500(self, nil)
        end
      end
    end
  end

  get '/inventory/:item_id/edit' do
    if !session[:user_id].nil? && !session[:permission_level].nil?
      if session[:permission_level] >= 2
        item = Inventory.first(:id => params["item_id"])

        if item.nil?
          return status 404
        else
          return slim(:"update-inventory-item", :locals => {
              :item_id => params["item_id"],
              :item_name => item.name,
              :item_barcode => item.barcode,
              :item_category => item.category,
              :item_quantity => item.quantity,
              :item_description => item.description,
              :action => "edit"
          })
        end
      end
    end

    ErrorHandler.e_403(self, nil)
  end

  patch '/inventory/:item_id/edit' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        item = Inventory.first(:id => params["item_id"])

        unless item.nil?
          item_update = {
              :name => params["item-name"],
              :barcode => params["item-barcode"],
              :quantity => params["item-quantity"].to_i,
              :description => params["item-description"],
              :category => params["item-category"],
              :stock_quantity => params["item-quantity"].to_i
          }

          if item.update(item_update)
            unless params[:"item-picture"].nil?
              if File.exists?("./public/product_images/product_#{params["item_id"]}.jpg")
                File.delete("./public/product_images/product_#{params["item_id"]}.jpg")
              end

              File.open("./public/product_images/product_#{params["item_id"]}.jpg", "w") do |file|
                file.write(params[:"item-picture"][:tempfile].read)
              end
            end

            redirect "/inventory/#{params["item_id"]}"
          end
        end
      end
    end

    ErrorHandler.e_403(self, nil)
  end

  delete '/inventory/:item_id/delete' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        unless params["item_id"].nil?
          item = Inventory.first(:id => params["item_id"])

          if item.delete
            if File.exists?("./public/product_images/product_#{params["item_id"]}.jpg")
              File.delete("./public/product_images/product_#{params["item_id"]}.jpg")
            end

            redirect '/inventory'
          else
            ErrorHandler.e_500(self, nil)
          end
        end
      end
    end

    ErrorHandler.e_403(self, nil)
  end

  get '/inventory/:item_id' do
    if params[:item_id] != nil && params[:item_id] != ''
      if params[:item_id][0..1] == 'b-'
        response = {:status => 'false'}
        if params["origin"] != nil && params["origin"].to_i == 2
          barcode = params[:item_id][2..-1]
          item = Inventory.first(:barcode => barcode)

          if item != nil
            response[:status] = 'true'
            response[:item] = {
                :id => item.id,
                :name => item.name,
                :quantity => item.quantity,
                :description => item.description,
                :barcode => item.barcode
            }
          else
            response[:status_msg] = "Coudn't find the item with barcode: #{barcode}"
          end
        else
          redirect("/inventory/#{Inventory.first(:barcode => params[:item_id][2..-1]).id}")
        end
        response.to_json
      else
        item = Inventory.first(:id => params[:item_id])
        if item != nil
          q = 0
          if item.quantity > 0
            q = item.quantity
          end

          inventory_item_names = []
          Inventory.all(:order => [:name, :asc]).each do |i|
            inventory_item_names << i.name
          end

          slim :item_page, :locals => {
              :item_id => item.id,
              :item_name => item.name,
              :item_quantity => q,
              :item_description => item.description.nil? || item.description == '' ? 'Description to be added' : item.description,
              :item_category => item.category.nil? ? 0 : item.category,
              :item_category_name => item.category.nil? ? "Alla" : Categories.first(:id => item.category).name,
              :inventory_item_names => inventory_item_names
          }
        else
          redirect '/inventory'
        end
      end
    else
      redirect '/inventory'
    end
  end

  get '/wiki' do
    slim :wiki
  end
end