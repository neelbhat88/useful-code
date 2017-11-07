class ChartDataService
  attr_accessor :job_query, :education_query, :years_post_degree_query,
                :result, :public_data_size,
                :currency, :compensation_type

  def initialize
    @currency = ReferenceData::CURRENCY::USD
    @compensation_type = ReferenceData::COMPENSATION_TYPE::SALARY
  end

  def set_filters(args)
    @company_filters = args.slice(:industry_id, :function_id, :city_id, :job_type, :company_id, :position_id,
                                  :startup, :startup_stage, :visa_sponsorship, :data_recency)

    @company_mapped_filters = args.slice(:company_list_id, :job_function_id)
    if @company_mapped_filters[:company_list_id] && @company_filters[:company_id].blank?
      @company_filters[:company_id] = @company_mapped_filters[:company_list_id]
    end

    if @company_mapped_filters[:job_function_id] && @company_filters[:function_id].blank?
      @company_filters[:function_id] = @company_mapped_filters[:job_function_id]
    end

    @education_filters = args.slice(:degree_id, :school_id, :program, :major_id, :degree_type)
    @years_post_degree_str = args[:years_post_degree]
  end

  def overwrite_defaults(args)
    @currency = args[:currency] if args[:currency]
    @compensation_type = args[:compensation_type] if args[:compensation_type]
  end

  def percentile_chart(args={})
    compensation_amount = args[:compensation_amount]
    benchmark_metric = args[:benchmark_metric] || "Total Compensation"

    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    column_name = Company::BENCHMARK_COLUMNS[benchmark_metric]

    query = Company
            .select(
              "percentile_cont(0.1) within group (order by #{column_name}) as tenth_percentile",
              "percentile_cont(0.25) within group (order by #{column_name}) as twenty_fifth_percentile",
              "percentile_cont(0.5) within group (order by #{column_name}) as median",
              "percentile_cont(0.75) within group (order by #{column_name}) as seventy_fifth_percentile",
              "percentile_cont(0.90) within group (order by #{column_name}) as ninetieth_percentile",
              "MIN(#{column_name}) AS min",
              "MAX(#{column_name}) AS max",
              "COUNT(#{column_name}) AS count"
            )

    query = if compensation_amount
              query.select(
                "percent_rank(#{compensation_amount}) within group (order by #{column_name}) as percent_rank"
              )
            else
              query.select(
                "ARRAY_AGG(#{column_name}) AS array_agg_column"
              )
            end

    query = query.where("#{column_name} IS NOT NULL")
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    @job_query = query.to_sql
    @result = query.to_a.first
  end

  def compensation_percentiles(args={})
    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    columns = case @compensation_type
              when ReferenceData::COMPENSATION_TYPE::SALARY
                %w[total_comp salary bonus signing_bonus relocation_bonus stock_comp misc_comp]
              when ReferenceData::COMPENSATION_TYPE::HOURLY
                %w[hourly_wage]
              when ReferenceData::COMPENSATION_TYPE::FIXED
                %w[fixed_amount]
              else
                %w[total_comp salary bonus]
              end

    query = Company
    columns.each do |column|
      query = query
              .select(
                "percentile_cont(0.1) within group (order by #{column}) as tenth_percentile_#{column}",
                "percentile_cont(0.25) within group (order by #{column}) as twenty_fifth_percentile_#{column}",
                "percentile_cont(0.5) within group (order by #{column}) as median_#{column}",
                "percentile_cont(0.75) within group (order by #{column}) as seventy_fifth_percentile_#{column}",
                "percentile_cont(0.90) within group (order by #{column}) as ninetieth_percentile_#{column}",
                "MIN(#{column}) AS min_#{column}",
                "MAX(#{column}) AS max_#{column}",
                "SUM(case when #{column} is null then 0 else 1 end) as count_#{column}"
              )
    end

    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    @job_query = query.to_sql
    @result = query.to_a.first

    attributes = @result.attributes
    return_object = {}
    columns.each do |column|
      return_object[column] = {
        tenth_percentile: attributes["tenth_percentile_#{column}"],
        twenty_fifth_percentile: attributes["twenty_fifth_percentile_#{column}"],
        median: attributes["median_#{column}"],
        seventy_fifth_percentile: attributes["seventy_fifth_percentile_#{column}"],
        ninetieth_percentile: attributes["ninetieth_percentile_#{column}"],
        min: attributes["min_#{column}"],
        max: attributes["max_#{column}"],
        count: attributes["count_#{column}"]
      }
    end

    return_object
  end

  def stacked_chart(chart_type, args={})
    limit = args[:limit]

    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company
    query = add_chart_type_statements(query, chart_type)
    query = add_stacked_chart_select_statements(query)
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    query = query.order("count DESC, chart_object_id DESC")
    query = query.limit(limit) if limit.present?

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  # TODO: Delete after GET /positions/:id call in positions_controller is deleted
  def average_satisfaction_metrics(args={})
    chart_type = args[:chart_type]
    limit = args[:limit]

    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company
            .select(
              "ROUND(AVG(hours_worked), 1) AS average_hours_worked",
              "ROUND(AVG(travel_percent), 1) AS average_travel_percent",
              "ROUND(AVG(culture), 1) AS average_culture",
              "ROUND(AVG(impact), 1) AS average_impact",
              "ROUND(AVG(overall_happiness), 1) AS average_overall_happiness",
              "ROUND(AVG(recommend), 1) AS average_recommend",
              "COUNT(*) as count"
            )
    query = query.where(offer: false)

    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)
    query = add_chart_type_statements(query, chart_type)

    query = query.limit(limit) if limit.present?

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  def stacked_chart_with_satisfaction(chart_type, args={})
    limit = args[:limit] || 10
    offset = args[:offset]

    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company
    query = add_chart_type_statements(query, chart_type)
    query = query.select(
      "COUNT(*) FILTER (WHERE visa_sponsorship <> 'No' and visa_sponsorship is not null) AS visa_sponsorship_count"
    )
    query = add_stacked_chart_select_statements(query)
    query = add_satisfaction_select_statements(query)
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    query = query.order("count DESC, chart_object_id DESC")
    query = query.limit(limit) if limit
    query = query.offset(offset) if offset

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  def stacked_chart_no_compensation(chart_type, args={})
    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company
    query = add_chart_type_statements(query, chart_type)
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    query = query.order("chart_object_id DESC")

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  def gender_count(args={})
    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company.joins("INNER JOIN users u on u.id = companies.user_id")
    query = query.select("DISTINCT ON (user_id) user_id")
    query = query.order("user_id")
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    user_query = User
    user_query = user_query
                 .select("SUM(case when (gender = 'Male' or gender = 'Female') then 1 else 0 end) as count_users",
                         "SUM(case when gender = 'Female' then 1 else 0 end) as count_female")
                 .where(id: query)

    @job_query = user_query.to_sql
    @result = user_query.to_a

    @result.first
  end

  def offer_timeline(args={})
    set_filters(args)

    overwrite_defaults(args.slice(:currency, :compensation_type))

    query = Company.offer
                   .select("start_month as month, count(*) as offer_count")
                   .where.not(start_month: [nil, ""])
                   .group("start_month")
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)

    @job_query = query.to_sql
    @result = query.to_a

    @result.map {|d| d.slice("month", "offer_count").symbolize_keys }
  end

  def salary_trends(args={})
    set_filters(args)
    overwrite_defaults(args)

    query = Company.select(:compensation_start_year)
    query = add_stacked_chart_select_statements(query)
    query = query.where("cast(compensation_start_year as int) > ?", Time.zone.now.year - 10)
    query = query.group(:compensation_start_year)
    query = query.having("SUM(case when public_data=true then 1 else 0 end) > 0")
    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)
    query = query.order("compensation_start_year ASC")

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  def salary_feed(args={})
    set_filters(args)
    overwrite_defaults(args)

    query = Company.select(:id, :start_month, :start_year)
                   .joins(:position)
                   .select("positions.id as position_id, positions.position as position_name")
                   .joins(:company_list)
                   .select("company_lists.id as company_list_id, company_lists.name as company_list_name")
                   .where(public_data: true)

    case @compensation_type
    when ReferenceData::COMPENSATION_TYPE::SALARY
      query = query.select(:salary, :bonus, :other_comp, :misc_comp, :signing_bonus, :stock_comp, :relocation_bonus)
    when ReferenceData::COMPENSATION_TYPE::HOURLY
      query = query.select(:hourly_wage)
    end

    query = add_default_where_clauses(query)
    query = add_filter_where_clauses(query)
    query = query.order("to_date(start_month || ' ' || start_year, 'Mon Year') DESC")
    query = query.limit(10)

    @job_query = query.to_sql
    @result = query.to_a

    @result
  end

  def format_result
    @result.map(&:attributes)
  end

  private

  def add_default_where_clauses(query)
    query = query.where(
      reviewed: true,
      complete: true,
      currency: @currency,
      compensation_type: @compensation_type
    )

    query
  end

  def add_stacked_chart_select_statements(query)
    case @compensation_type
    when ReferenceData::COMPENSATION_TYPE::SALARY
      query = query
              .select(
                "MEDIAN(misc_comp) AS average_misc_comp",
                "MEDIAN(stock_comp) AS average_stock_comp",
                "MEDIAN(relocation_bonus) AS average_relocation_bonus",
                "MEDIAN(signing_bonus) AS average_signing_bonus",
                "MEDIAN(bonus) AS average_bonus",
                "MEDIAN(salary) AS average_salary",
                "MEDIAN(other_comp) AS average_other_comp",
                "COUNT(*) AS count"
              )
    when ReferenceData::COMPENSATION_TYPE::HOURLY
      query = query
              .select(
                "MEDIAN(hourly_wage) AS average_hourly_wage",
                "COUNT(*) as count"
              )
    end

    query
  end

  def add_satisfaction_select_statements(query)
    query = query
            .select(
              "ROUND(AVG(hours_worked), 1) AS average_hours_worked",
              "ROUND(AVG(travel_percent), 1) AS average_travel_percent",
              "ROUND(AVG(overall_happiness), 1) AS average_overall_happiness",
              "ROUND(AVG(coworker_quality), 1) as average_coworker_quality",
              "ROUND(AVG(advancement), 1) as average_advancement",
              "ROUND(AVG(training_development), 1) as average_training_development",
              "ROUND(AVG(brand_prestige), 1) as average_brand_prestige",
              "ROUND(AVG(benefits_perks), 1) as average_benefits_perks",
              "ROUND(AVG(firm_stability), 1) as average_firm_stability",
              "ROUND(AVG(balance_flexibility), 1) as average_balance_flexibility",
              "SUM(case when overall_happiness is null then 0 else 1 end) as count_satisfaction"
            )

    query
  end

  def add_chart_type_statements(query, chart_type)
    case chart_type
    when "position"
      query = query.joins(:position)
                   .select("positions.position AS chart_object_name,
                            position_id as chart_object_id,
                            companies.job_type as job_type,
                            COUNT(position_id) OVER() AS full_count")
                   .group("chart_object_id, chart_object_name, job_type")
                   .having("SUM(case when public_data=true then 1 else 0 end) > 0")
    when "industry"
      query = query.joins(:industry)
                   .select("industries.name AS chart_object_name,
                            industry_id as chart_object_id,
                            description,
                            negotiation_index,
                            COUNT(industry_id) OVER() AS full_count")
                   .group("chart_object_name, industry_id, description, negotiation_index")
    when "function"
      query = query.joins(:function)
                   .select("functions.name AS chart_object_name,
                            function_id as chart_object_id,
                            description,
                            negotiation_index,
                            COUNT(function_id) OVER() AS full_count")
                   .group("chart_object_name, function_id, description, negotiation_index")
    when "company"
      query = query.joins(:company_list)
                   .select("company_lists.name AS chart_object_name,
                            company_list_id as chart_object_id,
                            COUNT(company_list_id) OVER() AS full_count")
                   .group("chart_object_name, company_list_id")
                   .having("SUM(case when public_data=true then 1 else 0 end) > 0")
    end

    query
  end

  def add_culture_chart_type_statements(query, chart_type)
    case chart_type
    when "position"
      query = query.joins(:position)
                   .select("positions.position AS chart_object_name,
                            position_id as chart_object_id,
                            companies.job_type as job_type,
                            COUNT(position_id) OVER() AS full_count")
                   .group("chart_object_id, chart_object_name, job_type")
                   .having("SUM(case when public_sat_data=true then 1 else 0 end) > 0")
    when "industry"
      query = query.joins(:industry)
                   .select("industries.name AS chart_object_name,
                            industry_id as chart_object_id,
                            description,
                            negotiation_index,
                            COUNT(industry_id) OVER() AS full_count")
                   .group("chart_object_name, industry_id, description, negotiation_index")
    when "function"
      query = query.joins(:function)
                   .select("functions.name AS chart_object_name,
                            function_id as chart_object_id,
                            description,
                            negotiation_index,
                            COUNT(function_id) OVER() AS full_count")
                   .group("chart_object_name, function_id, description, negotiation_index")
    when "company"
      query = query.joins(:company_list)
                   .select("company_lists.name AS chart_object_name,
                            company_list_id as chart_object_id,
                            COUNT(company_list_id) OVER() AS full_count")
                   .group("chart_object_name, company_list_id")
                   .having("SUM(case when public_sat_data=true then 1 else 0 end) > 0")
    end

    query
  end

  def add_filter_where_clauses(query)
    unless @education_filters.blank? && @years_post_degree_str.blank?
      query = query.where(id: build_education_sub_query)
    end

    query = add_optional_where_clauses(query)

    query
  end

  def add_optional_where_clauses(query)
    query = query.where(industry_id: @company_filters[:industry_id])    if @company_filters[:industry_id].present?
    query = query.where(function_id: @company_filters[:function_id])    if @company_filters[:function_id].present?
    query = query.where(city_id: @company_filters[:city_id])            if @company_filters[:city_id].present?
    query = query.where(company_list_id: @company_filters[:company_id]) if @company_filters[:company_id].present?
    query = query.where(job_type: @company_filters[:job_type])          if @company_filters[:job_type].present?
    query = query.where(position_id: @company_filters[:position_id])    if @company_filters[:position_id].present?

    query = query.where(startup: @company_filters[:startup])            if @company_filters[:startup].present?
    query = query.where(startup_stage: @company_filters[:startup_stage]) if @company_filters[:startup_stage].present?
    query = query.where(visa_sponsorship: @company_filters[:visa_sponsorship]) if @company_filters[:visa_sponsorship].present?
    if @company_filters[:data_recency] && @company_filters[:data_recency] != "insignificant quantum fluctuation"
      data_year_start = Time.zone.now.year - @company_filters[:data_recency].to_i
      query = query.where("compensation_start_year >= '?'", data_year_start)
    end

    query
  end

  def build_education_sub_query
    year_difference = if @years_post_degree_str.present?
                        YearsPostDegree.convert_select_option(@years_post_degree_str)
                      else
                        -1..50 # All jobs during/AFTER the current degree
                      end

    query = Education.select("DISTINCT(years_post_degrees.company_id)")
                     .joins(:years_post_degrees)
                     .joins(:degree)
                     .where(years_post_degrees: {year_difference: year_difference})

    query = query.where(degrees: {degree_type: @education_filters[:degree_type]}) if @education_filters[:degree_type]
    query = query.where(degree_id: @education_filters[:degree_id]) if @education_filters[:degree_id]
    query = query.where(school_id: @education_filters[:school_id]) if @education_filters[:school_id]
    query = query.where(program: @education_filters[:program]) if @education_filters[:program]
    query = query.where(major_id: @education_filters[:major_id]) if @education_filters[:major_id]

    query
  end
end
