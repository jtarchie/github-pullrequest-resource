module Filters
  class Context
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if input.source.every
        @pull_requests
      else
        @memoized ||= @pull_requests.select do |pr|
          Octokit.statuses(input.source.repo, pr.sha).select do |status|
            status['context'] =~ /^concourse-ci/
          end.empty?
        end
      end
    end

    private

    attr_reader :input
  end
end
