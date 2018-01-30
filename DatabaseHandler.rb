module DatabaseHandler

  def self.init(db_path:)
    $db_path = db_path
    $database = SQLite3::Database.new(db_path)
  end

  class Table
    def self.attribute(name, type)
      @attributes ||= []
      @attributes << {
           :name => name,
           :type => type
      }
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

    def self.all(condition = {})
      begin
        unless condition.empty?
          con = "WHERE "
          condition.each_with_index do |key, index|
            con += "#{key[0]} = #{key[1]}"
            if index < condition.length - 1
              con += " and "
            end
          end
        end

        elements = []
        p "SELECT * FROM #{@table_name} #{con}"
        $database.execute("SELECT * FROM #{@table_name} #{con}").each do |element|
          values = {}
          @attributes.each_with_index do |attribute, index|
            values[attribute[:name]] = element[index]
          end
          elements << DatabaseHandler::DatabaseObject.new(@table_name, values)
        end
        elements
      rescue => e
        p e
        nil
      end
    end

    def self.first(condition = {})
      if condition.empty?
        element = $database.execute("SELECT * FROM #{@table_name}").first
      else
        element = $database.execute("SELECT * FROM #{@table_name} WHERE #{condition.keys.first} = ?", condition[condition.keys.first]).first
      end

      if element.nil?
        nil
      else
        values = {}
        @attributes.each_with_index do |attribute, index|
          values[attribute[:name]] = element[index]
        end
        DatabaseHandler::DatabaseObject.new(@table_name, values)
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

        if $database.execute("INSERT INTO #{@table_name} (#{columns}) VALUES (#{question_marks})", *values).empty?
          true
        end
        false
      rescue => e
        p e
        false
      end
    end
  end

  class DatabaseObject
    def initialize(table_name, values)
      @table_name = table_name
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
    end
  end
end