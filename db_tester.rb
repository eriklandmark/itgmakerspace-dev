require 'sqlite3'
require 'pp'

require_relative 'DatabaseHandler'
require_relative 'database/models'

DatabaseHandler.init(db_path: "database/database.sqlite")