module Sinatra
  module RoutesSessions
    def self.registered(app)
      app.get '/login' do
        redirect '/session/new'
      end

      app.get '/logout' do
        redirect '/session/delete'
      end

      app.get '/register' do
        redirect '/users/new'
      end

      app.get '/session/new' do
        if logged_in?
          redirect "/users/#{session[:user_id]}"
        else
          slim :login
        end
      end

      app.delete '/session/delete' do
        session[:user_id] = nil
        redirect '/'
      end

      app.post '/session' do
        user = Users.first(:email => params['user_email'].downcase)
        if !logged_in?
          if user != nil
            if BCrypt::Password.new(user.password) == params['user_password']
              session[:user_id] = user.id
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
    end
  end

  register RoutesSessions
end