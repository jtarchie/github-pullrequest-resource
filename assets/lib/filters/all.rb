# frozen_string_literal: true

require 'octokit'
require_relative '../pull_request'

module Filters
  class All
    def initialize(pull_requests: [], input: Input.instance)
      @input = input
    end

    def pull_requests
      if input.version.pr.nil?
        @pull_requests ||= Octokit.pulls(input.source.repo, pull_options).map {
          |pr| PullRequest.new(pr: pr)
        }
      else
        pr = Octokit.pull_request(input.source.repo, input.version.pr)
        pr.head.sha = input.version.ref
        last_pr = PullRequest.new(pr: pr)
        @pull_requests ||= Octokit.pulls(input.source.repo, pull_options).map {
          |pr| PullRequest.new(pr: pr)
        }.reject {
          |pr| pr.id == last_pr.id and pr.sha == last_pr.sha
        }.unshift(last_pr)
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
