# Adds `.raw_hash` to AR queries. So I can do User.select(:id).raw_hash to return the raw SQL hash
module Skillet
  extend ActiveSupport::Concern

  def raw_hash
    query = to_sql
    ActiveRecord::Base.connection.execute(query)
  end
end

ActiveRecord::Base.send(:include, Skillet)
