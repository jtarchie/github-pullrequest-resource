module Filters
  class CISkip
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      unless @input.source.disable_ci_skip
        @memoized ||= @pull_requests.delete_if { |pr| pr.latest_commit_message =~ /\[(ci skip|skip ci)\]/ }
      else
        @pull_requests
      end
    end
  end
end