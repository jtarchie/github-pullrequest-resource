# frozen_string_literal: true

require 'billy'

Billy.configure do |c|
  c.cache = true
  c.merge_cached_responses_whitelist = [/github/]
  c.non_successful_error_level = :error
  c.non_whitelisted_requests_disabled = true
end
