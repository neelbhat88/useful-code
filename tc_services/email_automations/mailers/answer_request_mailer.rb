module EmailAutomations
  class AnswerRequestMailer < ApplicationMailer
    before_action :set_vars

    def email_one
      send_mail subject: "We need you to answer Question #{@question.id}"
    end

    def email_two
      send_mail subject: "We need you to answer Question #{@question.id}"
    end

    def email_three
      send_mail subject: "We need you to answer Question #{@question.id}"
    end

    def email_four
      send_mail subject: "We need you to answer Question #{@question.id}"
    end

    private

    def set_vars
      @workflow_email = params[:workflow_email]

      @user = @workflow_email.user
      @question = Question.find(@workflow_email.question_id)
      @company_list = CompanyList.find(@workflow_email.company_list_id)
    rescue ActiveRecord::RecordNotFound => _e
      raise "Make sure goal_complete? has been called on the email object"
    end

    def send_mail(subject:)
      track extra: {campaign_id: @workflow_email.campaign.id, email_id: @workflow_email.id}

      mail to: @user.email, subject: subject, template_name: "email"
    end
  end
end
