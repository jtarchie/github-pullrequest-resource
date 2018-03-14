# frozen_string_literal: true

module Filters
  class Mergeable
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.only_mergeable

        @memoized ||= @pull_requests.delete_if do |pr|
          response = Octokit.pull_request(@input.source.repo, pr.id)
          !response['mergeable']
        end
      else
        @pull_requests
      end
    end
  end
end
