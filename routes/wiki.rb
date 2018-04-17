module Sinatra
  module RoutesWiki
    def self.registered(app)
      app.get '/wiki' do
        slim :wiki
      end

      app.get '/wiki/:page' do
        slim :"wiki/#{params[:page].gsub("-", "_")}"
      end
    end
  end

  register RoutesWiki
end