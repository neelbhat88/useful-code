class SqlQuerier
  def initialize(klass)
    @klass = klass
    @table_name = @klass.table_name

    @select_words = []
    @where_words = []
    @order_words = []
    @join_words = []

    @connection = ActiveRecord::Base.connection
  end

  def select(*columns)
    columns.each do |column|
      @select_words << if column.is_a?(Symbol)
                         tableize(column)
                       else
                         column
                       end
    end

    self
  end

  def where(clauses)
    if clauses.is_a?(String)
      @where_words << "(#{clauses})"
    elsif clauses.is_a?(Hash)
      @where_words << clauses.map {|k, v|
        if v.is_a?(Array)
          "#{tableize(k)} IN (#{v.join(', ')})"
        else
          "#{tableize(k)} = #{sanitize(v)}"
        end
      }
    end

    self
  end

  def order(*columns)
    columns.each do |column|
      @order_words << if column.is_a?(Symbol)
                        tableize(column) + " ASC"
                      else
                        column
                      end
    end

    self
  end

  # def joins(*tables)
  #   @join_clause = tables.map(&:to_s).map {|i|
  #     "INNER JOIN #{i} ON #{i}.id = #{@table_name}.#{i.singularize}_id"
  #   }.join(" ")
  #
  #   self
  # end

  def execute
    @connection.execute(query).as_json
  end

  def query
    select_clause + from_clause + where_clause + order_clause
  end

  def select_clause
    if @select_words.any?
      "SELECT #{@select_words.join(', ')} "
    else
      "SELECT * "
    end
  end

  def from_clause
    "FROM #{@klass.table_name}"
  end

  def where_clause
    return "" if @where_words.blank?

    " WHERE #{@where_words.join(' and ')}"
  end

  def order_clause
    return "" if @order_words.blank?

    " ORDER BY #{@order_words.join(', ')}"
  end

  private

  def tableize(key)
    "\"#{@table_name}\".\"#{key}\""
  end

  def sanitize(string)
    @connection.quote(string)
  end
end
