# Turns out `.as_json` does exactly what I was trying to do here.
# Oh well, at least this was fun to build
class SqlQuerier
  def initialize(klass)
    @klass = klass
    @table_name = @klass.table_name

    @select_words = []
    @where_words = []
    @order_words = []
    @join_words = []
    @group_words = []

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
          if v.include? nil
            v.delete(nil)
            "#{tableize(k)} IN (#{v.join(', ')}) OR #{tableize(k)} IS NULL"
          else
            "#{tableize(k)} IN (#{v.join(', ')})"
          end
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

  def joins(*clauses)
    clauses.each do |clause|
      if clause.is_a?(String)
        @join_words << clause
      elsif clause.is_a?(Symbol)
        join_table = table_name(clause)
        join_column = (clause.to_s + "_id").to_sym
        @join_words << "INNER JOIN #{join_table} on #{tableize(:id, join_table)} = #{tableize(join_column)}"
      elsif clause.is_a?(Hash)
        raise "Hash params in the joins are not yet supported! Use a string instead and then remind Neel to get on it."
      end
    end

    self
  end

  def group(*columns)
    columns.each do |column|
      @group_words << if column.is_a?(Symbol)
                        tableize(column)
                      else
                        column
                      end
    end

    self
  end

  def execute
    @connection.execute(query).as_json
  end

  def query
    select_clause + from_clause + join_clause + where_clause + order_clause + group_clause
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

  def join_clause
    return "" if @join_words.blank?

    " #{@join_words.join(' ')}"
  end

  def where_clause
    return "" if @where_words.blank?

    " WHERE #{@where_words.join(' and ')}"
  end

  def order_clause
    return "" if @order_words.blank?

    " ORDER BY #{@order_words.join(', ')}"
  end

  def group_clause
    return "" if @group_words.blank?

    " GROUP BY #{@group_words.join(', ')}"
  end

  private

  def tableize(key, table=nil)
    table ||= @table_name
    "\"#{table}\".\"#{key}\""
  end

  def sanitize(string)
    @connection.quote(string)
  end

  def table_name(symbol)
    symbol.to_s.classify.constantize.table_name
  end
end
