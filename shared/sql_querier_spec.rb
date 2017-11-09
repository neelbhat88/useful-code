#rubocop:disable all
require "rails_helper"

RSpec.describe SqlQuerier do
  context "selects" do
    it "handles no select" do
      query = SqlQuerier.new(Company).query
      expect(cleaned_query(query)).to eq("select * from companies")
    end

    it "handles symbols for select" do
      query = SqlQuerier.new(Company).select(:id, :salary).query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\", \"companies\".\"salary\" from companies")
    end

    it "handles strings for select" do
      query = SqlQuerier.new(Company).select("id", "salary as sal").query
      expect(cleaned_query(query)).to eq("select id, salary as sal from companies")
    end

    it "handles mixture of symbols and strings for select" do
      query = SqlQuerier.new(Company).select(:id, "salary", "count(*) as count").query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\", salary, count(*) as count from companies")
    end

    it "handles multiple selects" do
      query = SqlQuerier.new(Company).select(:id).select("salary").select("count(*) as count").query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\", salary, count(*) as count from companies")
    end
  end

  context "wheres" do
    it "handles hash values" do
      query = SqlQuerier.new(Company).where(reviewed: true, complete: true).where_clause
      expect(cleaned_query(query)).to eq("where \"companies\".\"reviewed\" = 't' and \"companies\".\"complete\" = 't'")
    end

    it "handles string values" do
      query = SqlQuerier.new(Company).where("reviewed = true and complete = true").where_clause
      expect(cleaned_query(query)).to eq("where (reviewed = true and complete = true)")
    end

    it "handles multiple wheres" do
      query = SqlQuerier.new(Company).where(reviewed: true).where("complete = true").where_clause
      expect(cleaned_query(query)).to eq("where \"companies\".\"reviewed\" = 't' and (complete = true)")
    end

    it "handles where with array value" do
      query = SqlQuerier.new(Company).where(id: [1, 2, 3]).where_clause
      expect(cleaned_query(query)).to eq("where \"companies\".\"id\" in (1, 2, 3)")
    end

    it "handles nil in array value" do
      query = SqlQuerier.new(Company).where(id: [nil, 2, 3]).where_clause
      expect(cleaned_query(query)).to eq("where \"companies\".\"id\" in (2, 3) or \"companies\".\"id\" is null")
    end
  end

  context "order_bys" do
    it "handles symbol values" do
      query = SqlQuerier.new(Company).order(:company_list_id, :id).order_clause
      expect(cleaned_query(query)).to eq("order by \"companies\".\"company_list_id\" asc, \"companies\".\"id\" asc")
    end

    it "handles string values" do
      query = SqlQuerier.new(Company).order("company_list_id asc", "id desc").order_clause
      expect(cleaned_query(query)).to eq("order by company_list_id asc, id desc")
    end

    it "handles both symbol and string values" do
      query = SqlQuerier.new(Company).order(:company_list_id, "id DESC").order_clause
      expect(cleaned_query(query)).to eq("order by \"companies\".\"company_list_id\" asc, id desc")
    end

    it "handles multiple orders" do
      query = SqlQuerier.new(Company).order("id DESC").order(:company_list_id).order_clause
      expect(cleaned_query(query)).to eq("order by id desc, \"companies\".\"company_list_id\" asc")
    end
  end

  context "group_bys" do

  end

  context "joins" do

  end

  context "full query" do
    it "select + from" do
      query = SqlQuerier.new(Company).select(:id, "salary", "count(*) as count").query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\", salary, count(*) as count from companies")
    end

    it "select + from + where" do
      query = SqlQuerier.new(Company)
                        .select(:id, "salary")
                        .where(company_list_id: 19, reviewed: true)
                        .query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\", salary from companies where \"companies\".\"company_list_id\" = 19 and \"companies\".\"reviewed\" = 't'")
    end

    it "select + from + where + order" do
      query = SqlQuerier.new(Company)
                        .select(:id)
                        .where(reviewed: true)
                        .order(:name)
                        .query
      expect(cleaned_query(query)).to eq("select \"companies\".\"id\" from companies where \"companies\".\"reviewed\" = 't' order by \"companies\".\"name\" asc")
    end

    it "select + from + order" do
      query = SqlQuerier.new(Company)
                        .select("salary")
                        .order("salary DESC")
                        .query
      expect(cleaned_query(query)).to eq("select salary from companies order by salary desc")
    end

    it "select + from + joins" do

    end

    it "select + from + joins + where + order + group" do

    end
  end

  def cleaned_query(query)
    query.downcase.strip
  end

  def tableize(table_name, key)
    "\"#{table_name}\".\"#{key}\""
  end
end
