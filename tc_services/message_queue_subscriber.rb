class MessageQueueSubscriber
  def self.queue(object:, action:, params:)
    job = MessageQueueSubscriberJob.perform_later(object: object, action: action, params: params)
    Rails.logger.info(
      "[MessageQueueSubscriber] Queued ActiveJob #{job.job_id}. Object: #{object} Action: #{action} Params: #{params}"
    )
  end

  def initialize(object:, action:, params: {})
    @object = object
    @action = action
    @params = params.symbolize_keys
  end

  def call
    case @object
    when "JobPost"
      handle_job_post_action
    when "CompanyData"
      handle_company_data_action
    when "CompanyBranding"
      handle_company_branding_action
    end
  end

  private

  def handle_job_post_action
    rows_cleared = DataCache.new(DataCache::RELEVANT_JOBS).clear_all

    rows_cleared = rows_cleared == false ? "[insert # of Jon's funny jokes here]" : rows_cleared
    message = "[MessageSubscriber] JobPost Action - Cleared #{rows_cleared} keys from RelevantJob cache."
    Rails.logger.info(message)
    SlackTechNotificationJob.perform_now(message) if ENV["MESSAGE_QUEUE_LOGGING"] == "verbose"
  end

  def handle_company_data_action
    company_id = @params[:company_id]

    rows_cleared = CacheService.clear_companies_explore(company_id)
    rows_cleared = rows_cleared == false ? "[insert # of Jon's funny jokes here]" : rows_cleared
    message = "[MessageSubscriber] CompanyData Action - Cleared #{rows_cleared} keys for Company page id #{company_id}."
    Rails.logger.info(message)
    SlackTechNotificationJob.perform_now(message)
  end

  def handle_company_branding_action
    company_id = @params[:komodo_id]
    company_params = @params.slice(:name, :logo_url, :cover_photo, :overview_live)

    company = CompanyList.find_by(id: company_id)
    return if company.nil?

    old_properties = company.attributes.symbolize_keys.slice(:name, :logo_url, :cover_photo, :overview_live)
    if company.update(company_params)
      message = "[MessageQueueSubscriber] CompanyList Action - Updating Komodo `CompanyList #{company.id}`
                 with params: ```#{JSON.pretty_generate(company_params)}```. Old params were:
                 ```#{JSON.pretty_generate(old_properties)}```"
      Rails.logger.debug(message)

      if ENV["MESSAGE_QUEUE_LOGGING"] == "verbose"
        SlackTechNotificationJob.perform_now(message)
      end
    else
      message = "[MessageQueueSubscriber] CompanyList Action - Failed to update Komodo `CompanyList #{company.id}`
                 with params: ```#{JSON.pretty_generate(company_params)}```"
      Rails.logger.debug(message)
      SlackTechNotificationJob.perform_now(message)
    end
  end
end
