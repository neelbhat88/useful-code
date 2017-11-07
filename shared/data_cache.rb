class DataCache
  RELEVANT_JOBS = "relevant-jobs".freeze
  BENCHMARK_DATA = "benchmark-data".freeze
  BENCHMARK_TOP_COMPANIES = "benchmark-top-companies".freeze
  BENCHMARK_TOP_POSITIONS = "benchmark-top-positions".freeze
  COMPANY_INFO = "company-info-overview".freeze

  def initialize(cache_key_base=nil)
    @cache_key_base = cache_key_base
  end

  def cache(cache_key_params)
    cache_key = build_cache_key(cache_key_params)

    log("CacheKey: #{cache_key}")

    return_object = Rails.cache.fetch(cache_key) do
      log("Cache Miss for cache_key: #{cache_key}!")
      yield
    end

    return_object
  end

  def clear_all
    CacheService.clear_data_cache(@cache_key_base)
  end

  def clear(cache_key_params)
    cache_key = build_cache_key(cache_key_params)

    CacheService.clear_key(cache_key)
  end

  private

  def log(message)
    Rails.logger.warn("[DATACACHE] #{message}")
  end

  def build_cache_key(cache_key_params)
    CacheService.cache_key(@cache_key_base, cache_key_params)
  end
end
