module EmailAutomations
  class AutomationRunner
    attr_reader :object, :action, :user

    def initialize
      @workflows = [
        EmailAutomations::MbaTwentySeventeenNoJobs
      ]
    end

    def perform(object:, action: nil)
      @object = object
      @action = action
      @user = object.try(:user)

      @workflows.each do |workflow|
        workflow.new(self).trigger?
      end
    end
  end
end
