require 'bundler'
Bundler.require
require 'sinatra/content_for'
require 'sinatra/default_charset'
require 'webrick/https'
require 'rack/ssl-enforcer'
require 'rack/rewrite'
require "net/https"
require "uri"
require 'pp'

require_relative 'DatabaseHandler'
require_relative 'app'
require_relative 'lib'

register Sinatra::DefaultCharset

configure :development do
  puts 'In Development Environment'

  DatabaseHandler.init(db_path: "database/database.sqlite")
  require_relative 'database/models'
  #update_inventory_items

  run App
end

class HTTPServer < Sinatra::Base
  use Rack::Rewrite do
    r301 %r{.*}, 'https://www.itgmaker.space$&'
  end

  get '/' do
    "Did not work"
  end
end

configure :production do
  puts 'In Production Environment'

  DatabaseHandler.init(db_path: "database/database.sqlite")
  require_relative 'database/models'
  update_inventory_items

  fork do
    Rack::Server.start({
        :Port => 80,
        :Host => '0.0.0.0',
        :SSLEnable => false,
        :app => HTTPServer
    })
  end

  Rack::Server.start({
      :Port               => 443,
      :Host               => '0.0.0.0',
      :SSLEnable          => true,
      :SSLVerifyClient    => OpenSSL::SSL::VERIFY_NONE,
      :SSLCertificate     => OpenSSL::X509::Certificate.new(File.open('ssl/itgmaker_space.crt').read),
      :SSLPrivateKey      => OpenSSL::PKey::RSA.new(File.open('ssl/itgmakerspace.key').read),
      :SSLCertName        => [['CN',WEBrick::Utils::getservername]],
      :app => App
  })
end
