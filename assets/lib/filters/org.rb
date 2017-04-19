module Filters
  class Org
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.org
        @memoized ||= @pull_requests.select do |pr|
          Octokit.organization_member?(@input.source.org, pr.user[:login])
        end
      else
        @pull_requests
      end
    end
  end
end
