module Sinatra
  module RoutesOrders
    def self.registered(app)
      app.get '/inkopslistor' do
        redirect '/orders'
      end

      app.get '/orders' do
        slim :orders
      end

      app.get '/orders/new' do
        if has_auth_level?(2)
          slim :new_order
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.post '/orders/new' do
        if has_auth_level?(2)
          order = {
              :name => params["order-name"],
              :description => params["order-description"],
              :date_created => DateTime.now,
              :date_due_by => params["date-due-by"]
          }

          if Orders.create(order)
            redirect "/admin/orders"
          else
            ErrorHandler.e_500(self, "Something wrong happened when updating item!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/orders/:order_id/edit' do
        if has_auth_level?(2)
          if Orders.first(:id => params["order_id"]).update({:name => params["order-name"], :description => params["order-description"], :date_due_by => params["date-due-by"]})
            redirect "/admin/orders"
          else
            ErrorHandler.e_500(self, "Something wrong happened when updating item!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/orders/:order_id/delete' do
        if has_auth_level?(2)
          order = Orders.first(:id => params["order_id"]){{:include => "items"}}
          if order.update({:status => Orders::INACTIVE}) && !order.items.nil?
            order.items.each do |item|
              unless item.update({:status => Orders::INACTIVE})
                ErrorHandler.e_500(self, nil)
              end
            end
          end

          redirect '/admin/orders'
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/orders/:order_id/items/new' do
        if logged_in?
          slim :new_order_item, :locals => {:order_id => params["order_id"]}
        else
          ErrorHandler.e_403(self, "Du måste vara inloggad för att kunna lägga till.")
        end
      end

      app.post '/orders/:order_id/items/new' do
        if logged_in?
          item = {
              :name => params["order-item-name"],
              :quantity => params["order-item-quantity"],
              :price => params["order-item-price"],
              :url => params["order-item-url"],
              :order_id => params["order_id"],
              :user_id => session[:user_id]
          }

          if Order_Items.create(item)
            redirect "/orders/#{params['order_id']}"
          else
            ErrorHandler.e_500(self, "Something wrong happened when adding item!")
          end
        else
          ErrorHandler.e_403(self, "Du måste vara inloggad för att kunna lägga till.")
        end
      end

      app.get '/orders/:order_id/items/:item_id/edit' do
        item = Order_Items.first(:id => params["item_id"], :order_id => params["order_id"], :status => Order_Items::ACTIVE)
        if has_auth_level?(2) || item.user_id == session[:user_id]
          slim :edit_order_item, :locals => {:order_id => params["order_id"], :item => item}
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.patch '/orders/:order_id/items/:item_id/edit' do
        item = Order_Items.first(:id => params["item_id"], :order_id => params["order_id"])
        if has_auth_level?(2) || item.user_id == session[:user_id]
          if item.update({
                             :name => params["order-item-name"],
                             :quantity => params["order-item-quantity"],
                             :price => params["order-item-price"],
                             :url => params["order-item-url"]
                         })
            redirect "/orders/#{params['order_id']}"
          else
            ErrorHandler.e_500(self, "Something wrong happened when adding item!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/orders/:order_id/items/:item_id/delete' do
        item = Order_Items.first(:id => params["item_id"], :order_id => params["order_id"])
        if has_auth_level?(2) || item.user_id == session[:user_id]
          if item.update({:status => Order_Items::INACTIVE})
            redirect "/orders/#{params['order_id']}"
          else
            ErrorHandler.e_500(self, "Something wrong happened when adding item!")
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.get '/orders/:order_id' do
        slim :order_page, :locals => {:order_id => params["order_id"]}
      end
    end
  end

  register RoutesOrders
end