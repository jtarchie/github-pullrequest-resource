# frozen_string_literal: true

module Filters
  class Fork
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.disable_forks
        @memoized ||= @pull_requests.delete_if(&:from_fork?)
      else
        @pull_requests
      end
    end
  end
end
