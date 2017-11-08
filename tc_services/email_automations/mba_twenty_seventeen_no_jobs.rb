module EmailAutomations
  class MbaTwentySeventeenNoJobs
    CLASS_YEAR = "2017".freeze

    def initialize(automation_runner)
      @automation_runner = automation_runner
      @object = @automation_runner.object
      @user = @automation_runner.user
    end

    def trigger?
      case @object.class.name
      when "Education", "Company"
        educations_count = @user.educations.where(class_year: CLASS_YEAR, degree_id: Degree.mba.id,
                                                  program: Education::PROGRAMS["full_time"]).count
        companies_count = @user.companies
                               .complete
                               .where("CAST(start_year as int) >= ?", CLASS_YEAR.to_i)
                               .count
        if educations_count > 0 && companies_count.zero?
          AnalyticsTracker.new(@user).email_automation(mba_2017_no_jobs: true)
        else
          AnalyticsTracker.new(@user).email_automation(mba_2017_no_jobs: false)
        end
      end
    end
  end
end
