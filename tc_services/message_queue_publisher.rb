class MessageQueuePublisher
  def self.queue(object, action, params={})
    job = MessageQueuePublisherJob.perform_later(object: object, action: action, params: params.as_json)
    Rails.logger.info(
      "[MessageQueuePublisher] Queued ActiveJob #{job.job_id}. Object: #{object} Action: #{action} Params: #{params}"
    )
  end

  def initialize(object:, action:, params: {})
    @object = object
    @action = action
    @params = params
  end

  def publish
    Zebra::MessageQueue.publish(@object, @action, @params)

  rescue => error
    message = "[MessageQueuePublisher] Zebra API request failed: #{error.message}"
    Rails.logger.error(message)
    SlackTechNotificationJob.perform_now(message)
  end
end
