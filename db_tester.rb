require 'sqlite3'
require 'pp'

require 'data_mapper'
require 'dm-migrations'
require 'dm-types'
require 'dm-aggregates'
require 'dm-sqlite-adapter'
require 'benchmark'

require_relative 'DatabaseHandler'

DatabaseHandler.init(db_path: "database/database.sqlite")
require_relative 'database/models'
require_relative 'lib'

pp Users.all {{:include => "loans"}}