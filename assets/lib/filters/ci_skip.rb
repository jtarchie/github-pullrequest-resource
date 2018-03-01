# frozen_string_literal: true

module Filters
  class CISkip
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if !@input.source.ci_skip
        @pull_requests
      else
        @memoized ||= @pull_requests.delete_if do |pr|
          latest_commit = Octokit.commit(@input.source.repo, pr.sha)
          latest_commit['commit']['message'] =~ /\[(ci skip|skip ci)\]/
        end
      end
    end
  end
end
