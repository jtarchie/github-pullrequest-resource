require 'octokit'
require_relative '../pull_request'

module Filters
  class All
    def initialize(pull_requests: [], input: Input.instance)
      @input = input
    end

    def pull_requests
      @pull_requests ||= Octokit.pulls(input.source.repo, pull_options).map do |pr|
        PullRequest.new(pr: Octokit.pull_request(input.source.repo, pr['number'], pull_options))
      end
    end

    private

    attr_reader :input

    def pull_options
      options = { state: 'open', sort: 'updated', direction: 'asc' }
      options[:base] = input.source.base if input.source.base
      options
    end
  end
end
