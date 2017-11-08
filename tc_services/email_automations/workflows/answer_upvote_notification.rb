module EmailAutomations
  module Workflows
    class AnswerUpvoteNotification
      include EmailAutomations::Lists

      LIST = LISTS[:answer_notifications]
      CAMPAIGN_ID = "answer_upvote_notification_campaign".freeze
      EMAILS = %w[email_one].freeze

      def self.start_workflow(args)
        answer_upvote_id = args[:answer_upvote_id]

        # Goal Completion
        answer_upvote = AnswerUpvote.where(id: answer_upvote_id).first
        return unless answer_upvote

        upvote_count = AnswerUpvote.where(answer_id: answer_upvote.answer_id).count
        return if upvote_count > 1

        # User opted out of list
        user_id_to_email = answer_upvote.answer.user_id
        opted_out = EmailOptOut.find_by(user_id: user_id_to_email, list: LIST)
        return if opted_out

        # Which email in workflow to send
        user_to_email = User.find(user_id_to_email)
        email_to_send = EMAILS.first
        # EMAILS.each do |email|
        #   next if user_to_email.messages.exists? campaign_id: CAMPAIGN_ID, email_id: email
        #
        #   email_to_send = email
        #   break
        # end

        # User already received email?
        # Nothing to do here

        # Send email
        EmailAutomations::AnswerUpvoteNotificationMailer.send(email_to_send, user: user_to_email).deliver_now
      end

      def initialize(automation_runner)
        @automation_runner = automation_runner
        @object = @automation_runner.object
        @action = @automation_runner.action
        @user = @automation_runner.user
      end

      def trigger?
        return unless @object.class.name == "AnswerUpvote" && @action == :add

        # Trigger background worker to send email
        wait_time = ENV["APP_ENV"] == "production" ? 1.hour : 1.minute
        EmailAutomationJob.set(wait: wait_time)
                          .perform_later(workflow: self.class.name, args: {answer_upvote_id: @object.id})
      end

      # def trigger?
      # end
      #
      # def goal_complete?
      # end
      #
      # def user_opted_out?
      # end
    end
  end
end
