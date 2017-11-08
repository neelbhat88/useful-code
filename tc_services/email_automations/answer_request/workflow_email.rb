module EmailAutomations
  module AnswerRequest
    class WorkflowEmail
      attr_reader :id, :campaign

      def initialize(email)
        @email = email

        @user = email.user
        @question_id = email.question_id
      end

      def id
        @id ||= @email.class.name.to_s
      end

      def campaign
        @campaign ||= AnswerRequest::Campaign.new
      end

      def trigger?
        if @user.messages.exists?(email_id: id) ||
           campaign.opted_out?(@user)
          return false
        end

        true
      end

      def goal_complete?
        company_list_id = @email.company_list_id
        Answer.exists? user_id: @user.id, company_list_id: company_list_id, question_id: @question_id
      end

      def deliver
        mailer_method = @email.class.name.split("::").last.underscore

        AnswerRequestMailer.with(workflow_email: @email).send(mailer_method).deliver_now
      end
    end
  end
end
