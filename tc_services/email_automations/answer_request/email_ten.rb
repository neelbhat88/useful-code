module EmailAutomations
  module AnswerRequest
    class EmailTen
      attr_reader :user, :company_list_id, :question_id

      def initialize(user_id:, workflow_email: nil)
        @user = User.find(user_id)
        @question_id = 10

        @workflow_email = workflow_email || AnswerRequest::WorkflowEmail.new(self)
      end

      def id
        @workflow_email.id
      end

      def campaign
        @workflow_email.campaign
      end

      def trigger?
        @workflow_email.trigger?
      end

      def goal_complete?(args)
        @company_list_id = args[:company_list_id]
        @workflow_email.goal_complete?
      end

      def deliver
        @workflow_email.deliver
      end

      def delay
        1.week
      end
    end
  end
end
