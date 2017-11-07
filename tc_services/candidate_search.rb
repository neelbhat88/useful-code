class CandidateSearch
  attr_accessor :education_query
  def initialize; end

  def search(args={})
    # Arrayify all keys
    args.keys.each {|k| args[k] = [args[k]] unless args[k].is_a?(Array) }

    @interest_filters = args.slice(:industry_interest_ids, :function_interest_ids, :location_interest_ids,
                                   :interested_company_ids)
    @company_filters = args.slice(:industry_ids, :function_ids, :company_ids)
    @edu_filters = args.slice(:degree_ids, :degree_types, :class_years, :school_ids, :programs, :major_ids,
                              :industry_ids, :function_ids)
    @work_auth_filters = args.slice(:usa_work_authorization, :requires_visa_sponsorship)
    @diversity_filters = args.slice(:genders, :races, :ethnicities)

    user_properties = {activated: true, job_notification_status: User::JobNotificationStatus::NOTIFY}
    if @work_auth_filters[:usa_work_authorization]
      user_properties[:usa_work_authorization] = @work_auth_filters[:usa_work_authorization]
    end
    if @work_auth_filters[:requires_visa_sponsorship]
      user_properties[:requires_visa_sponsorship] = @work_auth_filters[:requires_visa_sponsorship]
    end
    user_properties[:gender] = @diversity_filters[:genders] if @diversity_filters[:genders].present?
    user_properties[:race] = @diversity_filters[:races] if @diversity_filters[:races].present?
    user_properties[:ethnicity] = @diversity_filters[:ethnicities] if @diversity_filters[:ethnicities].present?

    query = Education.joins(:user)
                     .select(:user_id)
                     .where(users: user_properties)
    query = add_degree_clauses(query)
    query = add_class_year_clause(query)
    query = add_school_clause(query)
    query = add_program_clause(query)
    query = add_major_clause(query)

    query = query.where(user_id: company_sub_query) if company_sub_query
    query = query.where(user_id: user_interest_sub_query) if user_interest_sub_query

    query = query.order("users.completeness_score DESC, users.profile_score DESC")

    @education_query = query.to_sql
    query.pluck(:user_id).uniq
  end

  private

  def company_sub_query
    return nil unless @company_filters[:industry_ids] || @company_filters[:function_ids] ||
                      @company_filters[:company_ids]

    query = Company.select(:user_id)
                   .where(reviewed: true, complete: true, offer: false)

    query = query.where(industry_id: @company_filters[:industry_ids]) if @company_filters[:industry_ids]
    query = query.where(function_id: @company_filters[:function_ids]) if @company_filters[:function_ids]
    query = query.where(company_list_id: @company_filters[:company_ids]) if @company_filters[:company_ids]

    query
  end

  def user_interest_sub_query
    return nil unless @interest_filters[:industry_interest_ids] || @interest_filters[:function_interest_ids] ||
                      @interest_filters[:location_interest_ids] || @interest_filters[:interested_company_ids]

    query = User.select(:id)
                .joins("LEFT JOIN industry_interests on users.id = industry_interests.user_id")
                .joins("LEFT JOIN location_interests on users.id = location_interests.user_id")
                .joins("LEFT JOIN function_interests on users.id = function_interests.user_id")
                .joins("LEFT JOIN interested_companies on users.id = interested_companies.user_id")

    if @interest_filters[:industry_interest_ids]
      query = query.where(industry_interests: {industry_id: @interest_filters[:industry_interest_ids]})
    end

    if @interest_filters[:function_interest_ids]
      query = query.where(function_interests: {function_id: @interest_filters[:function_interest_ids]})
    end

    if @interest_filters[:location_interest_ids]
      query = query.where(location_interests: {city_id: @interest_filters[:location_interest_ids] << nil})
    end

    if @interest_filters[:interested_company_ids]
      query = query.where(interested_companies: {company_list_id: @interest_filters[:interested_company_ids]})
    end

    query
  end

  def add_degree_clauses(query)
    where_clause = ""
    where_clause += "degree_id in (#{sqlize_array(@edu_filters[:degree_ids])})" if @edu_filters[:degree_ids]
    where_clause += " OR " if @edu_filters[:degree_ids] && @edu_filters[:degree_types]
    where_clause += "degrees.degree_type in (#{sqlize_array(@edu_filters[:degree_types])})" if @edu_filters[:degree_types]

    query = query.joins(:degree).where(where_clause) if where_clause

    query
  end

  def add_class_year_clause(query)
    return query if @edu_filters[:class_years].blank?

    @edu_filters[:class_years] = @edu_filters[:class_years].map(&:to_s)
    query = query.where(class_year: @edu_filters[:class_years])
    query
  end

  def add_school_clause(query)
    return query if @edu_filters[:school_ids].blank?

    query = query.where(school_id: @edu_filters[:school_ids])
    query
  end

  def add_program_clause(query)
    return query if @edu_filters[:programs].blank?

    query = query.where(program: @edu_filters[:programs])
    query
  end

  def add_major_clause(query)
    return query if @edu_filters[:major_ids].blank?

    query = query.where(major_id: @edu_filters[:major_ids])
    query
  end

  def sqlize_array(array)
    if array.first.is_a?(String)
      array.map {|a| "'#{a}'" }.join(", ")
    else
      array.join(", ")
    end
  end
end
