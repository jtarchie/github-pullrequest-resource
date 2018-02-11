module Filters
  class State
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.state
        @memoized ||= @pull_requests.select do |pr|
          @input.source.state.to_s.casecmp(pr.state.to_s).zero?
        end
      else
        @pull_requests
      end
    end
  end
end
