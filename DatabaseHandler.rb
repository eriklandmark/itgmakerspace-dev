module DatabaseHandler

  def self.init(db_path:)
    $db_path = db_path
    $database = SQLite3::Database.new(db_path)
  end

  class Table

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

    def self.table_name(name)
      @table_name = name
    end

    def self.get_attributes
      @attributes
    end

    def self.get_database_path
      $db_path
    end

    def self.get_table_name
      @table_name
    end

    def self.execute(str)
      $database.execute(str)
    end

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

    def self.belongs_to(method, klass, key_1, key_2)
      @relations ||= []
      @relations << {:method => method, :class => klass, :key_1 => key_1, :key_2 => key_2}
    end

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
            db_result = $database.execute("SELECT * FROM #{@table_name} INNER JOIN #{relation[:class].get_table_name} ON #{@table_name}.#{relation[:key_1]} = #{relation[:class].get_table_name}.#{relation[:key_2]}#{con_query[0]}#{con_query[1]}", *get_values_from_condition(condition))
            table_1_values = {}
            table_1 = db_result.first[0..@attributes.length - 1]
            @attributes.each_with_index do |attribute, index|
              table_1_values[attribute[:name]] = table_1[index]
            end
            db_result.each do |e|
              table_2_values = {}
              table_2 = e[@attributes.length..-1]
              relation[:class].get_attributes.each_with_index do |attribute, index|
                table_2_values[attribute[:name]] = table_2[index]
              end
              table_1_values[relation[:method].to_sym] ||= []
              table_1_values[relation[:method].to_sym] << DatabaseHandler::DatabaseObject.new(relation[:class].get_table_name, table_2_values)
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

    def self.count(*condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT COUNT(*) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e
        nil
      end
    end

    def self.max(attribute, *condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT MAX(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e
        nil
      end
    end

    def self.min(attribute, *condition)
      begin
        con_query = generate_condition_query(condition, nil)
        $database.execute("SELECT MIN(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e.backtrace
        nil
      end
    end

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
    def initialize(table_name, values)
      @table_name = table_name
      values.each do |key, value|
        self.instance_variable_set("@#{key}".to_sym, value)
        self.class.send(:attr_accessor, key)
      end
    end

    def update(elements)
      sql_str = "UPDATE #{@table_name} SET "
      values = []
      elements.each_with_index do |key, index|
        values << key[1]
        sql_str += "#{key[0]} = ?"
        if index < elements.length - 1
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