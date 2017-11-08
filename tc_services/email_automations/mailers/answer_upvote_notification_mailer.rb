module EmailAutomations
  class AnswerUpvoteNotificationMailer < ApplicationMailer
    def email_one(user:)
      @user = user
      track extra: {campaign_id: EmailAutomations::AnswerUpvoteNotification::CAMPAIGN_ID, email_id: __method__.to_s}
      mail to: @user.email, subject: "Someone found your answer helpful!"
    end
  end
end
