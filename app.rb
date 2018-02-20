class App < Sinatra::Base
  if settings.production?
    use Rack::SslEnforcer, :redirect_to => 'https://itgmaker.space'
  end

  helpers Sinatra::ContentFor

  enable :sessions
  set :session_secret, 'itg-makerspace'
  set :show_exceptions, false
  set :default_charset, 'utf-8'

  not_found do
    status 404
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (404)")
    slim :error_page, :locals => {:error_code => '404', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
  end

  error do
    status 500
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men det uppstod ett fel på serversidan.! (#{status})")
    body(slim :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'})
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
    slim :login, :locals => {:login_msg => nil}
  end

  post '/login' do
    user = Users.first(:email => params['user_email'].downcase)
    if user != nil
      if BCrypt::Password.new(user.password) == params['user_password']
        puts params['user_email'] + ' logged in!'
        session[:user_email] = params['user_email']
        session[:user_full_name] = user.name
        session[:user_id] = user.id
        session[:permission_level] = user.permission_level

        redirect '/'
      else
        'Wrong password!'
      end
    else
      params['user_email'] + " doesn't exist!"
    end
  end

  get '/register' do
    if session[:user_email] == nil
      slim :register
    else
      slim :error_page, :locals => {:error_code => '403', :error_code_msg => "Tyvärr! Du får inte tillgång till denna sida när du är inloggad.<br>Logga ut först för att få tillgång till denna sida."}
    end
  end

  post '/register' do
    uri = URI.parse("https://www.google.com/recaptcha/api/siteverify?response=#{params['g-recaptcha-response']}&secret=6LdrnTkUAAAAACJ0UTJYDXjV2oVl_DoQsfIVwXm1")
    success = false
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri
      response = http.request request
      success = JSON.parse(response.body)["success"]
    end

    if success
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
          "fail"
        end
      else
        slim :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
      end
    else
      status 500
      error_msg("-- #{request.ip} försökte registrera sig men blev stoppad av reCAPTCHA. (#{status})")
      body(slim :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'})
    end
  end

  post '/logout' do
    session[:user_email] = nil
    session[:user_full_name] = nil
    session[:user_id] = nil
    session[:permission_level] = nil
    redirect '/'
  end

  get '/my-loans' do
    begin
      loans_items = []
      user_id = Users.first(:email => session[:user_email]).id
      user_loans = Loans.all(:user_id => user_id, :order => [:loan_id, :asc])
      total_of_user_loans = Loans.max(:loan_id, :user_id => user_id)

      if total_of_user_loans != nil
        total_of_user_loans.times do |id|
          items = []
          date = ''
          user_loans.each do |loan|
            if loan.loan_id == (id + 1)
              date = loan.date_loaned
              items << {:item => loan.item, :quantity => loan.quantity, :item_id => loan.item_id, :loan_id => loan.loan_id}
            end
          end
          if items.length > 0
            loans_items << {:date => date.sub('_', ' kl '), :items => items}
          end
        end
      end
      slim :my_loans, :locals => {:loans_items => loans_items}
    rescue
      redirect '/'
    end
  end

  post '/check-user-information' do
    u = Users.first(:email => params['user_email'].downcase)
    if u != nil
      if BCrypt::Password.new(u.password) == params['user_password']
        'true'
      else
        'false'
      end
    else
      'false'
    end
  end

  post '/check-user-exist' do
    u = Users.first(:email => params['user_email'].downcase)
    if u == nil
      'true'
    else
      'false'
    end
  end

  get '/items' do
    redirect '/inventory'
  end

  get '/inventory' do
    inventory = []
    category = '0'
    search_term = params[:search_term]

    if search_term.nil?
      search_term = ""
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

  get '/inventory/:item_id' do
    if params[:item_id] != nil && params[:item_id] != ''
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
    else
      redirect '/inventory'
    end
  end

  get '/change-password' do
    user = Users.first(:email => session[:user_email])
    if user != nil
      slim :change_password, :locals => {:user_email => params[:user_email]}
    else
      error_msg("#{session[:user_email]} försökte ändra lösenord men fel uppstod: (404) User not found!")
      slim :change_password, :locals => {:error_code => '', :error_code_msg => 'Serverfel uppstod! Testa att logga ut och logga in igen!'}
    end
  end

  post '/change-password' do
    begin
      user = Users.first(:id => session[:user_id])
      if user != nil
        if BCrypt::Password.new(user.password) == params['user_password'] && params[:new_password_1] == params[:new_password_2]
          if user.update(:password => BCrypt::Password.create(params[:new_password_1]))
            session[:user_email] = nil
            session[:user_full_name] = nil
            session[:user_id] = nil
            session[:permission_level] = nil

            redirect '/login'
          end
        else
          'Wrong password!'
        end
      end
    rescue
      puts 'Fel uppstod! Lösenords ändring.'
    end
  end

  post '/auth' do
    response = {:status => 'false', :status_msg => ''}
    user = Users.first(:email => params['email'].downcase)
    if user != nil
      if BCrypt::Password.new(user.password) == params['password']
        response[:status] = 'true'
        response[:user_id] = user.id
        response[:security_key] = SecureRandom.hex(20)
        response[:name] = user.name
        response[:email] = user.email
        p user.update(:security_key => response[:security_key])
      else
        response[:status_msg] = 'Fel anvandarnamn eller lösenord. Försök igen!'
      end
    else
      response[:status_msg] = 'Fel användarnamn eller lösenord. Försök igen!'
    end
    response.to_json
  end

  post '/new-loan' do
    security_key = params['security_key']
    user_id = params['user_id']
    items = params['items']
    loan_id = Loans.max(:loan_id)

    if loan_id == nil
      loan_id = 1
    else
      loan_id += 1
    end

    user = Users.first(:id => user_id)

    if user == nil
      return "User doesn't exists!"
    end

    if user.security_key != security_key
      return "Security keys doesn't match!"
    end

    items = JSON.parse(items)
    date = Time.new.strftime('%Y-%m-%d_%H:%M:%S')

    items.each do |item|
      new_loan = {
          :user_id => user_id,
          :loan_id => loan_id,
          :date_loaned => date,
          :item => item['item'],
          :item_id => item['item_id'],
          :quantity => item['quantity']
      }
      unless Loans.create(new_loan)
        return 'Item did not save!'
      end

      unless delete_inventory_item(item_id: item['item_id'], quantity: item['quantity'])
        return 'Something went wrong with the database!'
      end
    end

    'true'
  end

  post '/get-all-user-loans' do
    security_key = params['security_key']
    user_id = params['user_id']
    response = {:status => 'false', :status_msg => ''}
    user = Users.first(:id => user_id)
    if user != nil && user.security_key == security_key
      items = []
      Loans.all(:user_id => user_id, :order => [:loan_id]).each do |loan|
        items << {:quantity => loan.quantity, :item_id => loan.item_id, :loan_id => loan.loan_id, :date_loaned => loan.date_loaned}
      end
      response[:status] = 'true'
      response[:items] = items
    end

    JSON.generate(response)
  end

  post '/remove-loan-item' do
    response = {:status => 'false'}

    begin
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
        if origin == 2
          security_key = params['security_key']
          if user.security_key == security_key
            item = Loans.first(:item_id => item_id, :loan_id => loan_id)
            if item != nil
              if item.quantity > quantity
                if item.update(:quantity => (item.quantity - quantity))
                  add_inventory_item(item_id: item_id, quantity: quantity)
                  response[:status] = 'true'
                end
              else
                old_quantity = item.quantity
                if item.delete
                  add_inventory_item(item_id: item_id, quantity: old_quantity)
                  response[:status] = 'true'
                end
              end
            end
          end
        elsif origin == 1
          item = Loans.first(:item_id => item_id, :loan_id => loan_id)
          if item != nil
            if item.quantity > quantity
              if item.update(:quantity => (item.quantity - quantity))
                add_inventory_item(item_id: item_id, quantity: quantity)
                response[:status] = 'true'
              end
            else
              old_quantity = item.quantity
              if item.delete
                add_inventory_item(item_id: item_id, quantity: old_quantity)
                response[:status] = 'true'
              end
            end
          end
        end
      end
    rescue
      puts 'Fel uppstod med när man skulle lämna tillbaka en lånad sak.'
    end

    response.to_json
  end

  post '/remove-all-loan-item' do
    user_id = params['user_id'].to_i
    security_key = params['security_key']
    user = Users.first(:id => user_id)
    if user != nil
      if user.security_key == security_key
        Loans.all(:user_id => user_id).each do |loan|
          unless loan.delete
            "false"
          end
        end
        "true"
      end
    end
    "false"
  end

  get '/error' do
    if params["id"] == "500"
      status 500
      error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men det uppstod ett fel på serversidan.! (#{status})")
      slim :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'}
    else
      status 404
      error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (404)")
      slim :error_page, :locals => {:error_code => '404', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
    end
  end

  get '/3d-skrivare' do
    slim :'3d-skrivare'
    #slim :under_construction
  end

  get '/add-inventory-item' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        return slim(:"add-inventory-item", :locals => {
            :item_id => "-1",
            :item_name => "",
            :item_category => 0,
            :item_quantity => 1,
            :item_description => ""
        })
      end
    end

    status 403
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (403)")
    slim :error_page, :locals => {:error_code => '403', :error_code_msg => 'Ledsen men du har inte tillåtelse till det här..'}
  end

  get '/edit-inventory-item/:item_id' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        item = Inventory.first(:id => params["item_id"])

        if item.nil?
          return status 404
        else
          return slim(:"add-inventory-item", :locals => {
              :item_id => params["item_id"],
              :item_name => item.name,
              :item_category => item.category,
              :item_quantity => item.quantity,
              :item_description => item.description
          })
        end
      end
    end

    status 403
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (403)")
    slim :error_page, :locals => {:error_code => '403', :error_code_msg => 'Ledsen men du har inte tillåtelse till det här..'}
  end

  post '/update-inventory-item' do
    unless session[:user_id].nil? && session[:permission_level].nil?
      if session[:permission_level] >= 2
        if params["item-id"] == "-1"
          id = Inventory.max(:id).to_i + 1
          item = Inventory.create({
              :id => id,
              :name => params["item-name"],
              :quantity => params["item-quantity"].to_i,
              :description => params["item-description"],
              :category => params["item-category"],
              :stock_quantity => params["item-quantity"].to_i
          })

          if item
            unless params[:"item-picture"].nil?
              if File.exists?("./public/product_images/product_#{params["item-id"]}.jpg")
                File.delete("./public/product_images/product_#{params["item-id"]}.jpg")
              end

              File.open("./public/product_images/product_#{params["item-id"]}.jpg", "w") do |file|
                file.write(params['item-picture'][:tempfile].read)
              end
            end

            redirect '/inventory'
          else
            status 500
          end
        else
          item = Inventory.first(:id => params["item-id"])

          unless item.nil?
            item_update = {
                :name => params["item-name"],
                :quantity => params["item-quantity"].to_i,
                :description => params["item-description"],
                :category => params["item-category"],
                :stock_quantity => params["item-quantity"].to_i
            }

            if item.update(item_update)
              unless params[:"item-picture"].nil?
                if File.exists?("./public/product_images/product_#{params["item-id"]}.jpg")
                  File.delete("./public/product_images/product_#{params["item-id"]}.jpg")
                end

                File.open("./public/product_images/product_#{params["item-id"]}.jpg", "w") do |file|
                  file.write(params[:"item-picture"][:tempfile].read)
                end
              end

              redirect "/inventory/#{params["item-id"]}"
            end
          end
        end
      end
    end

    status 403
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (403)")
    slim :error_page, :locals => {:error_code => '403', :error_code_msg => 'Ledsen men du har inte tillåtelse till det här..'}
  end

  get '/delete-inventory-item/:item_id' do
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
            status 500
          end
        end
      end
    end

    status 403
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (403)")
    slim :error_page, :locals => {:error_code => '403', :error_code_msg => 'Ledsen men du har inte tillåtelse till det här..'}
  end

  get '/society' do
    erb :society
  end
end