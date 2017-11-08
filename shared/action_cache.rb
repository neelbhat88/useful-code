# Usage from controller action:
#
# return_object = ActionCache.new(self).cache_request do
#   ... code here
#
#   {
#     object to cache here
#   }
# end
#
# render json: return_object
#
class ActionCache
  def initialize(controller)
    @controller = controller
    @controller_name = controller.controller_name
    @params = controller.params.permit!.to_h
  end

  def cache_request(cache_key_addition=nil)
    return yield if @params[:skip_cache] == true

    cache_key_base = "#{@params[:controller]}-#{@params[:action]}#{cache_key_addition}"
    cache_key = CacheService.cache_key(cache_key_base, @params.except(:skip_cache, :controller,
                                                                      :action, @controller_name.to_sym,
                                                                      @controller_name.singularize.to_sym))

    log("CacheKey: #{cache_key}")

    return_object = Rails.cache.fetch(cache_key) do
      log("Cache Miss for cache_key: #{cache_key}!")
      yield
    end

    return_object.to_json
  end

  private

  def log(message)
    Rails.logger.warn("[#{@params[:controller].upcase}] ##{@params[:action]} #{message}")
  end
end
