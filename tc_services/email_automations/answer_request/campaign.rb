module EmailAutomations
  module AnswerRequest
    class Campaign
      include EmailAutomations::Lists

      attr_reader :id

      def initialize; end

      def id
        @id ||= self.class.name.to_s
      end

      def emails
        [EmailOne,
         EmailTwo,
         EmailThree,
         EmailFour,
         EmailFive,
         EmailSix,
         EmailSeven,
         EmailEight,
         EmailNine,
         EmailTen]
      end

      def list
        LISTS.find {|i| i[:id] == "answer_requests" }[:id]
      end

      def opted_out?(user)
        EmailAutomations::EmailOptOut.exists? user_id: user.id, list: list
      end

      def start(user)
        return false unless campaign_is_active?

        email_to_queue = emails.first.new(user_id: user.id)

        # Start first email if user doesn't have it already && user has not opted out
        if EmailAutomations::EmailCampaignQueue.exists?(user_id: user.id, campaign_id: id) ||
           user.messages.exists?(email_id: email_to_queue.id) ||
           opted_out?(user)
          return false
        end

        queue_email(user_id: user.id, email_to_queue: email_to_queue)

        true
      end

      def process_queue(email_campaign_queue)
        return false unless campaign_is_active?

        email_id = email_campaign_queue.email_id
        user = User.find(email_campaign_queue.user_id)
        args = email_campaign_queue.args.symbolize_keys

        recent_company = Company.find(args[:most_recent_company_id]) if args[:most_recent_company_id]
        recent_company ||= most_recent_company(user)

        unless leave_campaign?(user: user, company: recent_company)
          email = email_id.constantize.new(user_id: user.id)

          email.deliver if email.trigger? && !email.goal_complete?(company_list_id: recent_company.company_list_id)

          next_email = next_email_to_queue(user_id: user.id, email_id: email.id)
          if next_email
            queue_email(user_id: user.id, email_to_queue: next_email,
                        args: {most_recent_company_id: recent_company.id})
          end
        end

        email_campaign_queue.destroy
      end

      def campaign_is_active?
        EmailAutomations::EmailCampaign.exists? campaign_id: id,
                                                status: EmailAutomations::EmailCampaign::STATUS[:active]
      end

      private

      def leave_campaign?(user:, company:)
        return true if company.nil? ||
                       opted_out?(user) ||
                       QuestionsService.new(user: user)
                                       .all_questions_answered?(company_list_id: company.company_list_id)

        false
      end

      def queue_email(user_id:, email_to_queue:, args: {})
        queue = EmailAutomations::EmailCampaignQueue.create(user_id: user_id, campaign_id: id,
                                                            email_id: email_to_queue.id,
                                                            queue_until: Time.zone.now + email_to_queue.delay,
                                                            args: args)

        EmailAutomationJob.set(wait: email_to_queue.delay).perform_later(queue.id)
      end

      def next_email_to_queue(user_id:, email_id:)
        email_objects = emails.map {|e| e.new(user_id: user_id) }
        return if email_id == email_objects.last.id

        current_idx = email_objects.index {|e| e.id == email_id }
        email_objects[current_idx + 1]
      end

      def most_recent_company(user)
        companies = user.companies.complete.job
        return nil unless companies.any?

        companies.where(end_year: nil).first || companies.order("end_year DESC").first
      end
    end
  end
end
