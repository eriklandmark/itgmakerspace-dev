module Sinatra
  module RoutesAdmin
    def self.registered(app)
      app.get '/admin' do
        if has_auth_level?(2)
          slim :admin
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.post '/admin/accounts/new' do
        if has_auth_level?(2)
          info = {
              :name => params["user-full_name"],
              :email => params["user-email"],
              :birth_date => params["user-birth_date"],
              :permission_level => params["user-auth_level"],
              :password => params["user-password"]
          }
          if Users.create(info)
            redirect '/admin/accounts'
          else
            ErrorHandler.e_500(self, "Could not create account!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/admin/accounts/:user_id' do
        if has_auth_level?(2)
          user = Users.first(:id => params["user_id"])
          info = {
              :name => params["user-full_name"],
              :email => params["user-email"],
              :birth_date => params["user-birth_date"],
              :permission_level => params["user-auth_level"]
          }

          unless params["user-password"].nil? || params["user-password"].empty?
            info[:password] = BCrypt::Password.create(params["user-password"])
          end
          if !user.nil? && user.update(info)
            redirect '/admin/accounts'
          else
            ErrorHandler.e_500(self, "User not found!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/admin/accounts/:user_id' do
        if has_auth_level?(2)
          if session[:user_id] == params["user_id"].to_i
            ErrorHandler.e_500(self, "Du kan inte ta bort dig själv!")
          else
            user = Users.first(:id => params["user_id"])
            if !user.nil? && user.delete
              redirect '/admin/accounts'
            else
              ErrorHandler.e_404(self, "User not found!")
            end
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.post '/admin/inventory/categories/new' do
        if has_auth_level?(2)
          if Categories.create({:name => params["category-name"]})
            redirect '/admin/inventory/categories'
          else
            ErrorHandler.e_500(self, "Couldn't create category!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/admin/inventory/categories/:category_id' do
        if has_auth_level?(2)
          category = Categories.first(:id => params["category_id"])
          if !category.nil? && category.delete
            redirect '/admin/inventory/categories'
          else
            ErrorHandler.e_500(self, "Category not found!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/admin/inventory/categories/:category_id' do
        if has_auth_level?(2)
          category = Categories.first(:id => params["category_id"])
          p category
          if !category.nil? && category.update({:name => params["category-name"]})
            redirect '/admin/inventory/categories'
          else
            ErrorHandler.e_500(self, "Category not found!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/admin/:page' do
        if has_auth_level?(2) && File.exists?("views/admin/#{params[:page]}.slim")
          slim :"admin/#{params[:page]}"
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/admin/:page/:action' do
        path = "#{params[:page]}-#{params[:action]}"
        if has_auth_level?(2) && File.exists?("views/admin/#{path}.slim")
          slim :"admin/#{path}", :locals => {:params => params}
        else
          ErrorHandler.e_403(self, nil)
        end
      end
    end
  end

  register RoutesAdmin
end