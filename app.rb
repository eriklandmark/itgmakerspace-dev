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
    erb :error_page, :locals => {:error_code => '404', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
  end

  error do
    status 500
    error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men det uppstod ett fel på serversidan.! (#{status})")
    body(erb :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'})
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
    user = User.first(:email => params['user_email'].downcase)
    if user != nil
      if BCrypt::Password.new(user.password) == params['user_password']
        puts params['user_email'] + ' logged in!'
        session[:user_email] = params['user_email']
        session[:user_full_name] = user.name
        session[:user_id] = user.id

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
      erb :register
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
      u = User.first(:email => params['email'].downcase)
      if u == nil && params['password1'] == params['password2']
        new_user = {
            :email => params['email'].downcase,
            :password => BCrypt::Password.create(params['password1']),
            :name => params['fullname'],
            :birth_date => params['birth']
        }

        user = User.create(new_user)
        if user.save
          erb :login, :locals => {:login_msg => "#{params['fullname']} är nu registrerad! Logga in nedan."}
        end
      else
        erb :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
      end
    else
      status 500
      error_msg("-- #{request.ip} försökte registrera sig men blev stoppad av reCAPTCHA. (#{status})")
      body(erb :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'})
    end
  end

  post '/logout' do
    user = User.first(:email => params['user_email'])
    if user != nil
      session[:user_email] = nil
      session[:user_full_name] = nil
      redirect '/'
    else
      params['user_email'] + " doesn't exist!"
    end
  end

  get '/my-loans' do
    begin
      loans_items = []
      user_id = User.first(:email => session[:user_email]).id
      user_loans = Loan.all(:user_id => user_id, :order => [:loan_id.asc])
      total_of_user_loans = Loan.max(:loan_id, :user_id => user_id)

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
    u = User.first(:email => params['user_email'].downcase)
    p params['user_email']
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
    u = User.first(:email => params['user_email'].downcase)
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
    db_inventory = nil
    category_limit = Category.max(:id)
    order_of = nil
    order_dir = ''
    category = '0'
    search_term = ''

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
            category = params[:category]
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

    if db_inventory != nil && db_inventory.length > 0
      if !(search_term.length > 0 && db_inventory.length < 2)
        db_inventory.each do |item|
          q = 0
          if item.quantity > 0
            q = item.quantity
          end

          item = {
              :id => item.id,
              :name => item.name,
              :barcode => item.barcode,
              :description => item.description.nil? || item.description == '' ? 'Description to be added' : item.description,
              :quantity => q,
              :category => item.category
          }

          inventory << item
        end

        slim :inventory, :locals => {:inventory => inventory, :category_name => Category.first(:id => category).name, :search_term => search_term}
      else
        redirect "/inventory/#{db_inventory.first.id}"
      end
    else
      if search_term.length > 0
        slim :inventory, :locals => {:search_term => search_term, :inventory => db_inventory, :category_name => Category.first(:id => category).name}
      else
        redirect '/inventory'
      end
    end
  end

  get '/inventory/:item_id' do
    if params[:item_id] != nil && params[:item_id] != ''
      item = Inventory_Item.first(:id => params[:item_id])
      if item != nil
        q = 0
        if item.quantity > 0
          q = item.quantity
        end

        inventory_item_names = []
        Inventory_Item.all(:order => [:name.asc]).each do |item|
          inventory_item_names << item[:name].to_s
        end

        slim :item_page, :locals => {
            :item_id => item.id,
            :item_name => item.name,
            :item_quantity => q,
            :item_description => item.description.nil? || item.description == '' ? 'Description to be added' : item.description,
            :item_category => item.category.nil? ? 0 : item.category,
            :item_category_name => item.category.nil? ? "Alla" : Category.first(:id => item.category).name,
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
    user = User.first(:email => session[:user_email])
    if user != nil
      slim :change_password, :locals => {:user_email => params[:user_email]}
    else
      error_msg("#{session[:user_email]} försökte ändra lösenord men fel uppstod: (404) User not found!")
      slim :change_password, :locals => {:error_code => '', :error_code_msg => 'Serverfel uppstod! Testa att logga ut och logga in igen!'}
    end
  end

  post '/change-password' do
    begin
      user = User.first(:id => session[:user_id])
      if user != nil
        if BCrypt::Password.new(user.password) == params['user_password'] && params[:new_password_1] == params[:new_password_2]
          if user.update(:password => BCrypt::Password.create(params[:new_password_1]))
            session[:user_email] = nil
            session[:user_full_name] = nil
            session[:user_id] = nil

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
    user = User.first(:email => params['email'].downcase)
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
    loan_id = Loan.max(:loan_id)

    if loan_id == nil
      loan_id = 1
    else
      loan_id += 1
    end

    user = User.first(:id => user_id)

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
      if !Loan.create(new_loan).save
        return 'Item did not save!'
      end

      if !delete_inventory_item(item_id: item['item_id'], quantity: item['quantity'])
        return 'Something went wrong with the database!'
      end
    end

    'true'
  end

  post '/get-all-user-loans' do
    security_key = params['security_key']
    user_id = params['user_id']
    response = {:status => 'false', :status_msg => ''}
    user = User.first(:id => user_id)
    if user != nil && user.security_key == security_key
      items = []
      Loan.all(:user_id => user_id, :order => [:loan_id]).each do |loan|
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
      user = User.first(:id => user_id)
      p origin
      if user != nil
        if origin == 2
          security_key = params['security_key']
          if user.security_key == security_key
            item = Loan.first(:item_id => item_id, :loan_id => loan_id)
            if item != nil
              if item.quantity > quantity
                if item.update(:quantity => (item.quantity - quantity))
                  add_inventory_item(item_id: item_id, quantity: quantity)
                  response[:status] = 'true'
                end
              else
                old_quantity = item.quantity
                if item.destroy
                  add_inventory_item(item_id: item_id, quantity: old_quantity)
                  response[:status] = 'true'
                end
              end
            end
          end
        elsif origin == 1
          item = Loan.first(:item_id => item_id, :loan_id => loan_id)
          if item != nil
            if item.quantity > quantity
              if item.update(:quantity => (item.quantity - quantity))
                add_inventory_item(item_id: item_id, quantity: quantity)
                response[:status] = 'true'
              end
            else
              old_quantity = item.quantity
              if item.destroy
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
    user = User.first(:id => user_id)
    if user != nil
      if user.security_key == security_key
        Loan.all(:user_id => user_id).each do |loan|
          if !loan.destroy
            return "false"
          end
        end
        return "true"
      end
    end
    return "false"
  end

  get '/error' do
    if params["id"] == "500"
      status 500
      error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men det uppstod ett fel på serversidan.! (#{status})")
      erb :error_page, :locals => {:error_code => '500', :error_code_msg => 'Ojdå.. Något hände! En rapport har skapats angående felet.'}
    else
      status 404
      error_msg("-- #{request.ip} försökte söka in på #{request.path_info} men blev nekad! (404)")
      erb :error_page, :locals => {:error_code => '404', :error_code_msg => 'Ledsen kompis kunde inte hitta det du sökte efter..'}
    end
  end

  get '/3d-skrivare' do
    slim :'3d-skrivare'
    #slim :under_construction
  end
end