module Sinatra
  module RoutesUsers
    def self.registered(app)
      app.get '/users/new' do
        if !logged_in?
          slim :register
        else
          ErrorHandler.e_403(self, "Tyvärr! Du får inte tillgång till denna sida när du är inloggad.<br>Logga ut först för att få tillgång till denna sida.")
        end
      end

      app.post '/users/new' do
        uri = URI.parse("https://www.google.com/recaptcha/api/siteverify?response=#{params['g-recaptcha-response']}&secret=6LdrnTkUAAAAACJ0UTJYDXjV2oVl_DoQsfIVwXm1")
        success = false
        Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          success = ::JSON.parse(http.request(Net::HTTP::Get.new(uri)).body)["success"]
        end

        if success && !logged_in?
          u = Users.first(:email => params['email'].downcase)
          if u == nil && params['password1'] == params['password2']
            new_user = {
                :email => params['email'].downcase,
                :password => BCrypt::Password.create(params['password1']),
                :name => params['fullname'],
                :birth_date => params['birth'],
                :permission_level => 1
            }

            if Users.create(new_user)
              redirect '/session/new'
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

      app.get '/users/:user_id/edit' do
        if params[:user_id].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => session[:user_id])
          if user != nil
            slim :"user-edit", :locals => {:params => params}
          else
            ErrorHandler.e_500(self, nil)
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/users/:user_id/edit/change-password' do
        if params[:user_id].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => session[:user_id])
          if user != nil
            slim :"user-change-password", :locals => {:params => params}
          else
            ErrorHandler.e_500(self, nil)
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/users/:user_id/edit' do
        if params[:user_id].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => params["user_id"])
          info = {
              :name => params["user-full_name"],
              :email => params["user-email"],
              :birth_date => params["user-birth_date"]
          }

          if !user.nil? && user.update(info)
            redirect "/users/#{params[:user_id]}"
          else
            ErrorHandler.e_500(self, "User not found!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/users/:user_id/edit/change-password' do
        if params[:user_id].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => session[:user_id])
          if user != nil
            if BCrypt::Password.new(user.password) == params['user_password'] && params[:new_password_1] == params[:new_password_2]
              if user.update(:password => BCrypt::Password.create(params[:new_password_1]))
                session[:user_id] = nil

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

      app.get '/loans' do
        redirect "/users/#{session[:user_id]}/loans"
      end

      app.get '/users/:user_id/loans' do
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
                  items << {:quantity => item.quantity, :item_id => item.item_id, :loan_id => loan.id, :date_loaned => loan.date_loaned, :name => Inventory.first(:id => item.item_id).name}
                end
              end
            end
            response[:status] = 'true'
            response[:items] = items
          else
            response[:status_msg] = "Ett fel uppstod med användaren. Försök att logga ut och logga in igen."
          end

          response.to_json
        elsif params["user_id"].to_i == session[:user_id] || has_auth_level?(2)
          slim :my_loans, :locals => {:params => params}
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.post '/users/:user_id/loans/new' do
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
        if user.nil?
          response[:status] = "false"
          response[:status_msg] = "User doesn't exists!"
        end

        if user.security_key != security_key
          response[:status] = "false"
          response[:status_msg] = "Error with user verification try to logout and login again."
        end

        if response[:status] == "true"
          items = ::JSON.parse(items)
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

              unless Inventory.delete_inventory_item(item_id: item['item_id'], quantity: item['quantity'])
                response[:status] = "false"
                response[:status_msg] = "Couldn't update inventory!"
              end
            end
          end
        end

        response.to_json
      end

      app.post '/users/:user_id/loans/delete' do
        response = {:status => 'false'}
        origin = params['origin'].to_i
        user_id = params['user_id'].to_i
        item_id = params['item_id'].to_i
        loan_id = params['loan_id'].to_i
        quantity = params['quantity'].to_i
        user = Users.first(:id => user_id)
        if user != nil
          proceed = false
          if origin == 2 && params['security_key'] != nil && user.security_key == params['security_key']
            proceed = true
          elsif origin == 1 && (user_id == session[:user_id] || has_auth_level?(2))
            proceed = true
          end

          item = Loan_Items.first(:item_id => item_id, :loan_id => loan_id, :status => Loan_Items::ACTIVE)
          if item != nil && proceed
            if item.quantity > quantity
              if item.update(:quantity => (item.quantity - quantity))
                Inventory.add_inventory_item(item_id: item_id, quantity: quantity)
                response[:status] = 'true'
              end
            else
              old_quantity = item.quantity
              if item.update({:status => Loan_Items::INACTIVE})
                Inventory.add_inventory_item(item_id: item_id, quantity: old_quantity)
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

      app.post '/users/:user_id/loans/delete-all' do
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

      app.patch '/users/:user_id/profile-picture/edit' do
        if params["user_id"].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => params["user_id"]) {{:include => "loans"}}
          if !user.nil? && !params["user-profile-picture"].nil?
            path = "public/profile_images/profile_#{params["user_id"]}.#{params[:"user-profile-picture"][:filename].split('.')[-1]}"
            Dir.foreach("public/profile_images").each do |file|
              File.delete(File.join("public/profile_images", file)) if file.include?(params["user_id"].to_s)
            end

            if params[:"user-profile-picture"][:type].include?("image")
              File.open(path, "w") do |file|
                file.write(params[:"user-profile-picture"][:tempfile].read)
              end
              redirect "/users/#{params['user_id']}"
            else
              return ErrorHandler.e_500(self, "You didn't upload a image file. Try again!")
            end
          else
            ErrorHandler.e_404(self, "Användaren med id '#{params["user_id"]}' finns inte..")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/users/:user_id/profile-picture/delete' do
        if params["user_id"].to_i == session[:user_id] || has_auth_level?(2)
          Dir.foreach("public/profile_images").each do |file|
            File.delete(File.join("public/profile_images", file)) if file.include?(params["user_id"].to_s)
          end

          redirect "/users/#{params['user_id']}"
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/users/:user_id' do
        if params["user_id"].to_i == session[:user_id] || has_auth_level?(2)
          user = Users.first(:id => params["user_id"]) {{:include => "loans"}}
          if !user.nil?
            slim :user_page, :locals => {:user => user}
          else
            ErrorHandler.e_404(self, "Användaren med id '#{params["user_id"]}' finns inte..")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end
    end
  end

  register RoutesUsers
end