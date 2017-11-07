class MatchScoreCalculator
  def initialize(job_value_preference)
    @job_value_preference = job_value_preference
    @value_params = %i(coworker_quality advancement training_development brand_prestige
                       benefits_perks firm_stability balance_flexibility)
  end

  def calculate_for_companies(company_list_ids)
    matched_companies = []

    companies_with_percentile = company_query_with_percentile
                                .where(id: company_list_ids)
                                .order("name DESC")
    companies_with_percentile.each do |company_with_percentile|
      unless @job_value_preference.nil?
        match_score = user_match_score(company_with_percentile)
        breakdown = company_score_breakdown(company_with_percentile)
      end

      matched_companies << MatchedCompany.new(company_with_percentile, match_score: match_score,
                                                                       breakdown: breakdown)
    end

    matched_companies
  end

  def calculate_for_company(company_list_id)
    matched_companies = calculate_for_companies([company_list_id])

    matched_companies.first
  end

  def normalized_for_employer(company_list_id)
    company_with_percentile = company_query_with_percentile.find(company_list_id)

    if @job_value_preference
      match_score = calculate_normalized_score(company_with_percentile)
      breakdown = @job_value_preference.attributes.symbolize_keys.slice(*@value_params)
    end

    MatchedCompany.new(company_with_percentile, match_score: match_score, breakdown: breakdown)
  end

  private

  def company_query_with_percentile
    CompanyList
      .select(:id, :name, :domain, :company_logo, :logo_url)
      .joins("LEFT JOIN company_value_percentiles on company_value_percentiles.company_list_id = company_lists.id")
      .select(*@value_params)
  end

  def user_match_score(company_with_percentile)
    return if company_with_percentile.attributes.symbolize_keys.slice(*@value_params).values.include? nil

    match_score(company_with_percentile)
  end

  def calculate_normalized_score(company_with_percentile)
    company_percentiles = company_with_percentile.attributes.symbolize_keys.slice(*@value_params)
    return if company_percentiles.values.include? nil

    values_hash = company_percentiles.sort_by {|_k, v| -v }.to_h
    top_two_values = values_hash.values.slice(0, 2)

    possible_company_max = (0.5 * top_two_values.first) + (0.5 * top_two_values.last)

    match_score(company_with_percentile, possible_company_max)
  end

  def match_score(company_with_percentile, max_score=1)
    raw_score = 0
    @value_params.each do |value|
      raw_score += @job_value_preference[value] * company_with_percentile[value]
    end

    ((raw_score / max_score) * 100).round(0)
  end

  def company_score_breakdown(company_with_percentile)
    company_percentiles = company_with_percentile.attributes.symbolize_keys.slice(*@value_params)
    return {} if company_percentiles.values.include? nil

    company_percentiles
  end
end
