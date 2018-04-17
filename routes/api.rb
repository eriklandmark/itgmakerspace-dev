module Sinatra
  module RoutesApi
    def self.registered(app)
      app.post '/api/user-authentication' do
        response = {:status => "false"}
        sec_key = SecureRandom.hex(20)
        if params['user_email'].nil?
          user = Users.first(:id => session[:user_id])
        else
          user = Users.first(:email => params['user_email'].downcase)
        end

        if user != nil
          if BCrypt::Password.new(user.password) == params['user_password'] && user.update(:security_key => sec_key)
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

      app.post '/api/user-exists' do
        response = {:status => "true"}
        unless Users.first(:email => params['user_email'].downcase).nil?
          response[:status] = "false"
        end
        response.to_json
      end
    end
  end

  register RoutesApi
end