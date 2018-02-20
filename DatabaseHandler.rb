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

    private def create_table(name,attributes)
      begin
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
        puts e
        false
      end
    end

    def self.init_table
      begin
        table_exists = $database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='#{@table_name}';")
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
                    p_attribute[:primary_key] != attribute[:primary_key]
                  alter_table = true
                end
              end
            end
          end

          if alter_table
            $database.execute("DROP TABLE IF EXISTS tmp_#{@table_name}")
            $database.execute("ALTER TABLE #{@table_name} RENAME TO tmp_#{@table_name}")
            query = ""
            columns = ""
            same_columns = column_a & column_b
            same_columns.each_with_index do |column, index|
              columns += column
              if index < same_columns.length - 1
                columns += ", "
              end
            end

            create_table(@table_name, @attributes)

            $database.execute("CREATE TABLE '#{@table_name}' (#{query})")
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

    def self.belongs_to(method, klass, key)
      @relations ||= []
      @relations << {:method => method, :class => klass, :key => key}
    end

    def self.all(*condition)
      begin
        con_query = generate_condition_query(condition)
        elements = []
        $database.execute("SELECT * FROM #{@table_name} #{con_query[0]}#{con_query[1]}", *get_values_from_condition(condition)).each do |element|
          element_values = {}
          @attributes.each_with_index do |attribute, index|
            element_values[attribute[:name]] = element[index]
          end
          elements << DatabaseHandler::DatabaseObject.new(@table_name, @relations, element_values)
        end
        elements
      rescue => e
        p e
        nil
      end
    end

    def self.first(*condition)
      begin
        con_query = generate_condition_query(condition)
        element = $database.execute("SELECT * FROM #{@table_name} #{con_query[0]}#{con_query[1]} LIMIT 1", *get_values_from_condition(condition)).first

        if element.nil? || element.empty?
          nil
        else
          values = {}
          @attributes.each_with_index do |attribute, index|
            values[attribute[:name]] = element[index]
          end
          DatabaseHandler::DatabaseObject.new(@table_name, @relations, values)
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

    def self.max(attribute, *condition)
      begin
        con_query = generate_condition_query(condition)

        $database.execute("SELECT MAX(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e
        nil
      end
    end

    def self.min(attribute, *condition)
      begin
        con_query = generate_condition_query(condition)

        $database.execute("SELECT MIN(#{attribute.to_s}) FROM #{@table_name} #{con_query[0]}", *get_values_from_condition(condition))[0][0].to_i
      rescue => e
        p e.backtrace
        nil
      end
    end

    def self.generate_condition_query(condition)
      con = ""
      order_of = ""
      i = 0
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
            order_of = " ORDER BY #{key[1][0]}"
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
                con += " #{key[0]} like ?"
              elsif key[1].keys.first == :is
                con += " #{key[0]} is ?"
              else
                puts "'#{key[1].keys.first.to_s}' is not a comparator."
              end
            else
              con += " #{key[0]} = ?"
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
    def initialize(table_name, relations, values)
      @table_name = table_name
      @relations = relations
      values.each do |key, value|
        self.instance_variable_set("@#{key}".to_sym, value)
        self.class.send(:attr_accessor, key)
      end

      def update(elements)
        sql_str = "UPDATE #{@table_name} SET "
        values = []
        elements.each_with_index do |key, index|
          values << key[1]
          sql_str += "#{key[0]} = ?"
          if index < elements.length - 1
            str += ", "
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

      def method_missing(m, *args, &block)
        if !@relations.nil?
          @relations.each do |method|
            if m == method[:method]
              return method[:class].all(method[:key] => @id)
            end
          end
        else
          method_missing(m, args, block)
        end
      end
    end
  end
end