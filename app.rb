class App < Sinatra::Base
  use Rack::MethodOverride

  helpers User_Authentication
  helpers Sinatra::ContentFor

  if settings.production?
    use Rack::SslEnforcer, :redirect_to => 'https://itgmaker.space'
  end

  enable :sessions
  set :session_secret, 'ff7b77ac25993778036046de614dd3f5dc2b4f6020bac1fe48d9f0a5433a'
  set :show_exceptions, false
  set :default_charset, 'utf-8'
  set :method_override, true

  not_found do
    ErrorHandler.e_404(self, nil)
  end

  error do
    ErrorHandler.e_500(self, nil)
  end

  register Sinatra::RoutesAdmin
  register Sinatra::RoutesApi
  register Sinatra::RoutesInventory
  register Sinatra::RoutesOrders
  register Sinatra::RoutesSessions
  register Sinatra::RoutesUsers
  register Sinatra::RoutesWiki


  get '/' do
    dates = nil
    File.open('meeting_dates.json', 'r') do |file|
      dates = JSON.parse(file.read)
    end
    year, month, day = ''
    hour = '15'

    dates['dates'].each do |date|
      if DateTime.new(date['year'].to_i, get_month_num_from_name(month: date['month']), date['day'].to_i, 15, 00, 00, '+1') > DateTime.now
        year = date['year']
        month = date['month']
        day = date['day']
        break
      end
    end
    slim :index, :locals => {:day => day, :year => year, :month => month, :hour => hour}
  end
end