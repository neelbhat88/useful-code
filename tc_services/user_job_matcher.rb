class UserJobMatcher
  attr_reader :relevant_job_ids

  def initialize(user)
    @user = user
  end

  def relevant_job_posts_with_score(args={})
    limit = args[:limit] || 10

    relevant_job_posts
    return [] if relevant_job_posts_total.zero?

    jobs_with_match_score(limit)
  end

  def relevant_job_posts_total
    relevant_job_posts if @relevant_job_ids.blank?

    @relevant_job_ids[:education].size
  end

  def relevant_job_posts
    @relevant_job_ids = {
      education: [],
      industry: [],
      function: [],
      location: []
    }

    return @relevant_job_ids if @user.educations.size.zero?

    industry_interests = @user.industry_interests.includes(:industry).pluck(:name)
    function_interests = @user.function_interests.includes(:function).pluck(:name)

    @job_posts = education_relevant_jobs
    @relevant_job_ids[:education] = @job_posts.map(&:id)
    @relevant_job_ids[:industry] = @job_posts.select {|jp| industry_interests.include? jp.industry.name }
                                             .map(&:id)
    @relevant_job_ids[:function] = @job_posts.select {|jp| function_interests.include? jp.function.name }
                                             .map(&:id)
    @relevant_job_ids[:location] = location_relevant_jobs.map(&:id)

    @relevant_job_ids
  end

  private

  def education_relevant_jobs
    education_requirements = Education.joins(:degree).where(user_id: @user.id).map {|e|
      {class_year: e.class_year, degree_id: e.degree_id, degree_type: e.degree.degree_type}
    }

    key = @user.educations.maximum(:updated_at).to_i
    return_object = DataCache.new(DataCache::RELEVANT_JOBS).cache(user_id: @user.id, key: key) do
      Zebra::JobPost.relevant_jobs(education_requirements)
    end

    return_object
  end

  def location_relevant_jobs
    user_city_names = @user.location_interests.includes(:city).pluck(:name)

    if user_city_names.include?(nil)
      @job_posts
    else
      @job_posts.select {|jp| user_city_names.include? jp.city.name }
    end
  end

  def jobs_with_match_score(limit)
    score100 = @relevant_job_ids[:education] & @relevant_job_ids[:industry] &
                @relevant_job_ids[:function] & @relevant_job_ids[:location]

    score75 =
      (
        (@relevant_job_ids[:education] & @relevant_job_ids[:industry] & @relevant_job_ids[:function]) |
        (@relevant_job_ids[:education] & @relevant_job_ids[:industry] & @relevant_job_ids[:location]) |
        (@relevant_job_ids[:education] & @relevant_job_ids[:function] & @relevant_job_ids[:location])
      ).flatten.uniq

    score50 =
      (
        (@relevant_job_ids[:education] & @relevant_job_ids[:industry]) |
        (@relevant_job_ids[:education] & @relevant_job_ids[:function]) |
        (@relevant_job_ids[:education] & @relevant_job_ids[:location])
      ).flatten.uniq

    score25 = @relevant_job_ids[:education]

    job_post_ids_with_scores = []
    job_post_ids_with_scores << score100.map {|s| {job_post_id: s, score: 100} }
    job_post_ids_with_scores << (score75 - score100).map {|s| {job_post_id: s, score: 75} }
    job_post_ids_with_scores << (score50 - score75 - score100).map {|s| {job_post_id: s, score: 50} }
    job_post_ids_with_scores << (score25 - score50 - score75 - score100).map {|s| {job_post_id: s, score: 25} }

    job_post_ids_with_scores = job_post_ids_with_scores.flatten

    job_post_ids_to_return = job_post_ids_with_scores.first(limit).map {|j| j[:job_post_id] }

    job_posts_to_return = @job_posts.select {|jp| job_post_ids_to_return.include? jp.id }

    company_list_ids = job_posts_to_return.map {|jp| jp.company.id }.uniq
    matched_companies = MatchScoreCalculator.new(@user.job_value_preference).calculate_for_companies(company_list_ids)

    job_posts_to_return.each do |jp|
      jp.relevancy_score = job_post_ids_with_scores.find {|j| j[:job_post_id] == jp.id }[:score]

      matched_company = matched_companies.find {|mc| mc.id == jp.company.id }
      jp.match_score = matched_company.match_score
      jp.breakdown = matched_company.breakdown
    end

    job_posts_to_return
  end
end
