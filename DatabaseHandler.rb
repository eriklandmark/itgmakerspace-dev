module DatabaseHandler

  # Initializing the DatabaseHandler.
  #
  # @param db_path [String] the path to the database file.
  # @return [nil].
  def self.init(db_path:)
    $db_path = db_path
    $database = SQLite3::Database.new(db_path)
  end

  class Table

    # Associates attributes for a table in the database to this class.
    #
    # @param args [array] An array of properties the attribute should have.
    # @return [nil].
    def self.attribute(*args)
      @attributes ||= []

      attribute = {
          :name => args[0].downcase,
          :type => args[1].upcase,
      }

      if !args[2].nil? && args[2].is_a?(Hash)
        attribute[:not_null] = args[2][:not_null].nil? ? false : args[2][:not_null]
        attribute[:primary_key] = args[2][:primary_key].nil? ? false : args[2][:primary_key]
        attribute[:unique] = args[2][:unique].nil? ? false : args[2][:unique]
        attribute[:default] = args[2][:default]
      else
        attribute[:not_null] = false
        attribute[:primary_key] = false
        attribute[:unique] = false
        attribute[:default] = nil
      end

      if attribute[:primary_key]
        attribute[:auto_increment] = args[2][:auto_increment].nil? ? false : args[2][:auto_increment]
      else
        attribute[:auto_increment] = false
      end

      @attributes << attribute
    end

    # Sets the table name for this class.
    #
    # @param name [String] The name of the table.
    # @return [String] Returns the table name.
    def self.table_name(name)
      @table_name = name
    end

    # Gets all the attributes associated to this table.
    #
    # @return [Array] Returns all the attributes associated to this table.
    def self.get_attributes
      @attributes
    end

    # Gets the path to the database on disk.
    #
    # @return [String] Returns the path.
    def self.get_database_path
      $db_path
    end

    # Gets the name of the table.
    #
    # @return [String] Returns the name of table.
    def self.get_table_name
      @table_name
    end

    # Takes in a string of sqlite code and executes it in the specified database.
    #
    # @param exe_str [String] Sqlite code.
    # @return [Array] Returns an array of database attributes.
    def self.execute(exe_str)
      $database.execute(exe_str)
    end

    # Takes in a name and an array of attributes for the table and creates it.
    #
    # @param name [String] Name of new table.
    # @param attributes [Array] Array of attributes for the new table.
    # @return [Boolean] Returns true or false depending if it succeeds or not.
    def self.create_table(name,attributes)
      begin
        query = ""
        attributes.each_with_index do |attribute, index|
          query += "'#{attribute[:name]}' #{attribute[:type]}"
          if attribute[:not_null]
            query += " NOT NULL"
          end
          if attribute[:unique]
            query += " UNIQUE"
          end
          if attribute[:primary_key]
            query += " PRIMARY KEY"
          end
          if attribute[:auto_increment]
            query += " AUTOINCREMENT"
          end
          unless attribute[:default].nil?
            query += " DEFAULT '#{attribute[:default]}'"
          end
          if index < attributes.length - 1
            query += ", "
          end
        end

        $database.execute("CREATE TABLE IF NOT EXISTS '#{name}' (#{query})")
        true
      rescue => e
        puts e.backtrace
        false
      end
    end

    # Initializes table with the specified attributes. It creates the table or alter it depending on the name and
    # attributes.
    #
    # @return [Boolean] Returns true or false depending if it succeeds or not..
    def self.init_table
      begin
        table_exists = $database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='#{@table_name}'")
        if table_exists.empty?
          create_table(@table_name, @attributes)
        else
          columns = $database.execute("PRAGMA table_info('#{@table_name}')")
          column_a = []
          column_b = []
          alter_table = false
          columns.each do |item_a|
            column_a << item_a[1].downcase
          end
          @attributes.each do |item_b|
            column_b << item_b[:name].downcase
          end

          if !(column_b - column_a).empty? || !(column_a - column_b).empty?
            alter_table = true
          end

          columns.each do |column|
            @attributes.each do |attribute|
              if column[1].downcase == attribute[:name].downcase
                p_attribute = {
                    :id => column[0],
                    :name => column[1],
                    :type => column[2].upcase,
                    :not_null => column[3] == 1,
                    :default => column[4] == "" ? nil : column[4],
                    :primary_key => column[5] == 1
                }

                unless p_attribute[:default].nil?
                  p_attribute[:default] = p_attribute[:default][1..-2]
                end

                if p_attribute[:not_null] != attribute[:not_null] ||
                    p_attribute[:default] != attribute[:default] ||
                    p_attribute[:primary_key] != attribute[:primary_key] ||
                    p_attribute[:type] != attribute[:type]
                  alter_table = true
                end
              end
            end
          end

          if alter_table
            $database.execute("DROP TABLE IF EXISTS tmp_#{@table_name}")
            $database.execute("ALTER TABLE #{@table_name} RENAME TO tmp_#{@table_name}")
            columns = ""
            same_columns = column_a & column_b
            same_columns.each_with_index do |column, index|
              columns += column
              if index < same_columns.length - 1
                columns += ", "
              end
            end
            create_table(@table_name, @attributes)
            $database.execute("INSERT INTO #{@table_name} (#{columns}) SELECT #{columns} FROM tmp_#{@table_name}")
            $database.execute("DROP TABLE tmp_#{@table_name}")
          end
        end
        true
      rescue => e
        puts "Error initiating table: #{@table_name}"
        puts e
        false
      end
    end

    # Adds relations between two tables to make join requests.
    #
    # @param method [Symbol] Name of the method.
    # @param klass [Class] Class to the other table in the relationship.
    # @param key_1 [Symbol] Unique key for the first table in the relationship.
    # @param key_2 [symbol] Unique key for the second table in the relationship.
    # @return [Nil]
    def self.belongs_to(method, klass, key_1, key_2)
      @relations ||= []
      @relations << {:method => method, :class => klass, :key_1 => key_1, :key_2 => key_2}
    end

    # Gets all the elements from database with matching conditions. If relation specified, also returns the elements of
    # the relating table.
    #
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @param block [Block] A block to specify if it shall include a relations elements.
    # @return [Array] Returns an array of DatabaseObjects representing the elements from the table.
    def self.all(*condition, &block)
      begin
        if block_given? && block != nil
          relation = nil
          @relations.each do |rel|
            if rel[:method].to_s == yield[:include]
              relation = rel
            end
          end
          if relation != nil
            con_query = generate_condition_query(condition, @table_name)
            elements = []
            $database.execute("SELECT * FROM #{@table_name} INNER JOIN #{relation[:class].get_table_name} ON #{@table_name}.#{relation[:key_1]} = #{relation[:class].get_table_name}.#{relation[:key_2]}#{con_query[0]}#{con_query[1]}", *get_values_from_condition(condition)).each do |e|
              table_1_values = {}
              table_2_values = {}
              table_1 = e[0..@attributes.length - 1]
              table_2 = e[@attributes.length..-1]
              @attributes.each_with_index do |attribute, index|
                table_1_values[attribute[:name]] = table_1[index]
              end
              relation[:class].get_attributes.each_with_index do |attribute, index|
                table_2_values[attribute[:name]] = table_2[index]
              end
              table_1_values[relation[:method].to_sym] ||= []
              table_1_values[relation[:method].to_sym] << DatabaseHandler::DatabaseObject.new(relation[:class].get_table_name, table_2_values)
              contains_element = false
              elements.each_with_index do |element, index|
                if element.instance_variable_get("@" + relation[:key_1].to_s) == table_1_values[relation[:key_1].to_s]
                  contains_element = true
                  rels = elements[index].instance_variable_get("@" + relation[:method].to_s)
                  rels << DatabaseHandler::DatabaseObject.new(relation[:class].get_table_name, table_2_values)
                  elements[index].instance_variable_set(("@" + relation[:method].to_s).to_sym, rels)
                end
              end
              unless contains_element
                elements << DatabaseHandler::DatabaseObject.new(@table_name, table_1_values)
              end
            end
            elements
          else
            all(*condition)
          end
        else
          con_query = generate_condition_query(condition, nil)
          elements = []
          $database.execute("SELECT * FROM #{@table_name} #{con_query[0]}#{con_query[1]}", *get_values_from_condition(condition)).each do |element|
            element_values = {}
            @attributes.each_with_index do |attribute, index|
              element_values[attribute[:name]] = element[index]
            end
            elements << DatabaseHandler::DatabaseObject.new(@table_name, element_values)
          end
          elements
        end
      rescue => e
        puts e.message
        puts e.backtrace
        nil
      end
    end

    # Gets the first element from database with matching conditions. If relation specified, also returns the elements of
    # the relating table.
    #
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @param block [Block] A block to specify if it shall include a relations elements.
    # @return [DatabaseObject] Returns an DatabaseObject representing the element from the table.
    def self.first(*condition, &block)
      begin
        if block_given? && block != nil
          relation = nil
          @relations.each do |rel|
            if rel[:method].to_s == yield[:include]
              relation = rel
            end
          end
          if relation != nil
            con_query = generate_condition_query(condition, @table_name)
            db_result = $database.execute("SELECT * FROM #{@table_name} LEFT JOIN #{relation[:class].get_table_name} ON #{@table_name}.#{relation[:key_1]} = #{relation[:class].get_table_name}.#{relation[:key_2]}#{con_query[0]}#{con_query[1]}", *get_values_from_condition(condition))
            table_1_values = {}
            table_1 = db_result.first[0..@attributes.length - 1]
            @attributes.each_with_index do |attribute, index|
              table_1_values[attribute[:name]] = table_1[index]
            end
            db_result.each do |e|
              table_2_values = {}
              table_2 = e[@attributes.length..-1]
              items_nil = true
              relation[:class].get_attributes.each_with_index do |attribute, index|
                unless table_2[index].nil?
                  items_nil = false
                end
                table_2_values[attribute[:name]] = table_2[index]
              end

              table_1_values[relation[:method].to_sym] ||= []
              if items_nil
                table_1_values[relation[:method].to_sym] = nil
              else
                table_1_values[relation[:method].to_sym] << DatabaseHandler::DatabaseObject.new(relation[:class].get_table_name, table_2_values)
              end
            end
            DatabaseHandler::DatabaseObject.new(@table_name, table_1_values)
          else
            first(*condition)
          end
        else
          con_query = generate_condition_query(condition, nil)
          element = $database.execute("SELECT * FROM #{@table_name} #{con_query[0]}#{con_query[1]} LIMIT 1", *get_values_from_condition(condition)).first
          if element.nil? || element.empty?
            nil
          else
            values = {}
            @attributes.each_with_index do |attribute, index|
              values[attribute[:name]] = element[index]
            end
            DatabaseHandler::DatabaseObject.new(@table_name, values)
          end
        end
      rescue => e
        p e.backtrace
        nil
      end
    end

    # Creates a new element in table with the values specified.
    #
    # @param element [Hash] An Hash containing all the values for the element.
    # @return [Boolean] Returns true or false if action succeeds or not.
    def self.create(element)
      begin
        columns = ""
        values = []
        question_marks = ""
        element.each_with_index do |key, index|
          columns += "#{key[0]}"
          question_marks += "?"
          values << key[1].to_s
          if index < element.length - 1
            columns += ", "
            question_marks += ", "
          end
        end
        $database.execute("INSERT INTO #{@table_name} (#{columns}) VALUES (#{question_marks})", *values)
        true
      rescue => e
        p e
        false
      end
    end

    # Counts all the element in table with the specified condition.
    #
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @return [Integer] Returns the number of elements found with the conditions.
    def self.count(*condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT COUNT(*) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e
        nil
      end
    end

    # Gets the max value of a element in table found with the specified condition.
    #
    # @param attribute [Symbol] The attribute to get data from.
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @return [Integer] Returns the value of elements found with the conditions.
    def self.max(attribute, *condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT MAX(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e
        nil
      end
    end

    # Gets the minimum value of a element in table found with the specified condition.
    #
    # @param attribute [Symbol] The attribute to get data from.
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @return [Integer] Returns the value of elements found with the conditions.
    def self.min(attribute, *condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT MIN(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e.backtrace
        nil
      end
    end

    # Gets the sum of elements in an attribute specified with condition.
    #
    # @param attribute [Symbol] The attribute to get data from.
    # @param condition [Array] An array of symbols, declaring the conditions.
    # @return [Integer] Returns the value of elements found with the conditions.
    def self.sum(attribute, *condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT SUM(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e.backtrace
        nil
      end
    end

    # Generates a string formatted for sqlite from the conditions given.
    #
    # @param condition [condtition] An array of symbols, declaring the conditions.
    # @param t_name [String] the table name to use with relations.
    # @return [String] Returns the string with the formatted conditions.
    def self.generate_condition_query(condition, t_name)
      con = ""
      order_of = ""
      i = 0
      if t_name == nil
        table_name = ""
      else
        table_name = t_name.to_s + "."
      end
      unless condition.nil? || condition.empty?
        condition.first.each do |key|
          if key[0] == :order
            i += 1
          end
        end
        if i < condition.first.length
          con = " WHERE"
        end
        condition.first.each_with_index do |key, index|
          if key[0] == :order
            order_of = " ORDER BY #{table_name + key[1][0].to_s}"
            if key[1][1] == :asc
              order_of += " ASC"
            elsif key[1][1] == :desc
              order_of += " DESC"
            else
              order_of += " ASC"
            end
          else
            if key[1].is_a?(Hash)
              if key[1].keys.first == :like
                con += " #{table_name + key[0].to_s} like ?"
              elsif key[1].keys.first == :is
                con += " #{table_name + key[0].to_s} is ?"
              else
                puts "'#{table_name + key[1].keys.first.to_s}' is not a comparator."
              end
            else
              con += " #{table_name + key[0].to_s} = ?"
            end
            if index < condition.first.length - (1 + i)
              con += " and"
            end
          end
        end
      end
      [con, order_of]
    end

    # Gets all the condition values to use in execute.
    #
    # @param condition [condtition] An array of symbols, declaring the conditions.
    # @return [Array] Returns an array with all the values.
    def self.get_values_from_condition(condition)
      values = []
      unless condition.nil? || condition.empty?
        condition.first.each do |key|
          unless key[0] == :order
            if key[1].is_a?(Hash)
              if key[1].keys.first == :like
                values << "%#{key[1][:like]}%"
              elsif key[1].keys.first == :is
                values << "#{key[1][:like]}"
              end
            else
              values << key[1].to_s
            end
          end
        end
      end
      values
    end
  end

  class DatabaseObject

    # Initializes and creates the DatabaseObject. Also creates the instance variables with element values.
    #
    # @param table_name [String] An array of symbols, declaring the conditions.
    # @param element_values [Array] An array of an elements values and names.
    # @return [Nil]
    def initialize(table_name, element_values)
      @table_name = table_name
      element_values.each do |key, value|
        self.instance_variable_set("@#{key}".to_sym, value)
        self.class.send(:attr_accessor, key)
      end
    end

    # Updates a value or values for the DatabaseObject in the table.
    #
    # @param element [Hash] An array of values and names too be updated.
    # @return [Boolean] Returns true or false if action succeeds or not.
    def update(element)
      sql_str = "UPDATE #{@table_name} SET "
      values = []
      element.each_with_index do |key, index|
        values << key[1]
        sql_str += "#{key[0]} = ?"
        if index < element.length - 1
          sql_str += ", "
        end
      end
      sql_str += " WHERE id = ?"
      values << @id
      begin
        $database.execute(sql_str, *values)
        true
      rescue => e
        p e
        false
      end
    end

    # Deletes this element from the database.
    #
    # @return [Boolean] Returns true or false if action succeeds or not.
    def delete
      begin
        $database.execute("DELETE FROM #{@table_name} WHERE id = ?", @id)
        true
      rescue => e
        p e
        false
      end
    end
  end
end