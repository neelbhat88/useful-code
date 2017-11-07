namespace :db do
  task update_years_post_degree: :environment do
    years_post_degree_objects = []
    companies = Company.where(reviewed: true, complete: true)

    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] Running update_years_post_degree for #{companies.size} company records"
    companies.find_each(batch_size: 500) do |company|
      Education.where(user_id: company.user_id).each do |education|
        year_difference = company.compensation_start_year.to_i - education.class_year.to_i
        years_post_degree_objects << {company_id: company.id, education_id: education.id, user_id: company.user_id,
                                      year_difference: year_difference}
      end
    end
    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] Creating #{years_post_degree_objects.size} years_post_degree records"
    values = years_post_degree_objects.map {|o|
      "(#{o[:company_id]},#{o[:education_id]},#{o[:user_id]},#{o[:year_difference]},'#{Time.zone.now}',
       '#{Time.zone.now}')"
    }.join(",")

    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] Truncating and re-creating years_post_degrees table"
    ActiveRecord::Base.connection.execute("TRUNCATE years_post_degrees RESTART IDENTITY;
                                           INSERT INTO years_post_degrees (company_id, education_id, user_id,
                                                                           year_difference, created_at, updated_at)
                                           VALUES #{values}")

    SlackTechNotificationJob.perform_later("Updated Years Post Degree table.")
    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] DONE!"

    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] Clearing Cached Data"
    num_deleted = CacheService.clear_data_cache
    Rails.logger.warn "[YEARS_POST_DEGREE_RAKE] #{num_deleted} Data cache keys cleared."
    SlackTechNotificationJob.perform_later("#{num_deleted} Data cache keys cleared.")
  end
end
