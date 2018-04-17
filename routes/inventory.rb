module Sinatra
  module RoutesInventory
    def self.registered(app)
      app.get '/inventory' do
        category = params[:category]
        search_term = params[:search_term]

        if search_term.nil?
          search_term = ""
        end
        if category.nil?
          category = "0"
        end

        db_inventory = Inventory.get_inventory(params: params)

        slim :inventory, :locals => {:inventory => db_inventory, :category_name => Categories.first(:id => category).name, :search_term => search_term}
      end

      app.post '/inventory/new' do
        if has_auth_level?(2)
          id = Inventory.max(:id).to_i + 1

          if Inventory.create({
                                  :id => id,
                                  :name => params["item-name"],
                                  :barcode => params["item-barcode"],
                                  :quantity => params["item-quantity"].to_i,
                                  :description => params["item-description"],
                                  :category => params["item-category"],
                                  :stock_quantity => params["item-quantity"].to_i,
                                  :specs => params["item-specs"] == ""? nil : params["item-specs"]
                              })
            unless params[:"item-picture"].nil?
              path = "public/product_images/product_#{id}.#{params[:"item-picture"][:filename].split('.')[-1]}"
              Dir.foreach("public/product_images").each do |file|
                File.delete(File.join("public/product_images", file)) if file.include?(id.to_s)
              end

              if params[:"item-picture"][:type].include?("image")
                File.open(path, "w") do |file|
                  file.write(params[:"item-picture"][:tempfile].read)
                end
              else
                return ErrorHandler.e_500(self, "You didn't upload a image file. Try again!")
              end
            end

            redirect '/admin/inventory'
          else
            ErrorHandler.e_500(self, nil)
          end
        end
      end

      app.patch '/inventory/:item_id' do
        if has_auth_level?(2)
          item = Inventory.first(:id => params["item_id"])

          unless item.nil?
            item_update = {
                :name => params["item-name"],
                :barcode => params["item-barcode"],
                :description => params["item-description"],
                :category => params["item-category"],
                :stock_quantity => params["item-quantity"].to_i,
                :specs => params["item-specs"] == ""? nil : params["item-specs"]
            }

            if item.update(item_update) && Inventory.update_quantity_from_loans(params["item_id"])
              unless params[:"item-picture"].nil?
                path = "public/product_images/product_#{params["item_id"]}.#{params[:"item-picture"][:filename].split('.')[-1]}"
                Dir.foreach("public/product_images").each do |file|
                  File.delete(File.join("public/product_images", file)) if file.include?(params["item_id"].to_s)
                end

                if params[:"item-picture"][:type].include?("image")
                  File.open(path, "w") do |file|
                    file.write(params[:"item-picture"][:tempfile].read)
                  end
                else
                  return ErrorHandler.e_500(self, "You didn't upload a image file. Try again!")
                end
              end

              redirect "/admin/inventory"
            else
              ErrorHandler.e_500(self, "Something wrong happened when updating item!")
            end
          end
        else
          ErrorHandler.e_403(self, nil)
        end
      end

      app.delete '/inventory/:item_id/delete' do
        if has_auth_level?(2)
          unless params["item_id"].nil?
            item = Inventory.first(:id => params["item_id"])

            if item.delete
              Dir.foreach("public/product_images").each do |file|
                File.delete(File.join("public/product_images", file)) if file.include?(params["item_id"].to_s)
              end

              redirect '/admin/inventory'
            else
              return ErrorHandler.e_500(self, nil)
            end
          end
        end

        ErrorHandler.e_403(self, nil)
      end

      app.get '/inventory/:item_id' do
        if params[:item_id] != nil && params[:item_id] != ''
          if params[:item_id][0..1] == 'b-'
            if params["origin"] != nil && params["origin"].to_i == 2
              response = {:status => 'false'}
              barcode = params[:item_id][2..-1]
              item = Inventory.first(:barcode => barcode)

              if item != nil
                response[:status] = 'true'
                response[:item] = {
                    :id => item.id,
                    :name => item.name,
                    :quantity => item.quantity,
                    :stock_quantity => item.stock_quantity,
                    :description => item.description,
                    :barcode => item.barcode,
                    :category => item.category
                }
              else
                response[:status_msg] = "Coudn't find the item with barcode: #{barcode}"
              end

              response.to_json
            else
              item = Inventory.first(:barcode => params[:item_id][2..-1])
              if item.nil?
                ErrorHandler.e_404(self, "Kunde inte hitta någon artikel med streckkoden: #{params[:item_id][2..-1]}")
              else
                redirect("/inventory/#{item.id}")
              end
            end
          else
            item = Inventory.first(:id => params[:item_id])
            if item != nil
              slim :item_page, :locals => {:item => item}
            else
              ErrorHandler.e_404(self, "Kunde inte hitta någon artikel med id: #{params[:item_id]}")
            end
          end
        else
          redirect '/inventory'
        end
      end
    end
  end

  register RoutesInventory
end