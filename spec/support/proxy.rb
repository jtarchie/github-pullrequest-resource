require 'billy'

Billy.configure do |c|
  c.cache = true
  c.merge_cached_responses_whitelist = [/github/]
  c.non_successful_error_level = :error
  c.non_whitelisted_requests_disabled = true
end

module StubCacheHandler
  def handle_request(method, url, headers, body)
    if response = super
      Billy::Cache.instance.store(method.downcase, url, headers, body, response[:headers], response[:status], response[:content])
      return response
    end
  end
end

Billy::StubHandler.prepend(StubCacheHandler)
