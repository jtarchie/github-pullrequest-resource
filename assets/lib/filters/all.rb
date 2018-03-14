# frozen_string_literal: true

require 'octokit'
require_relative '../pull_request'

module Filters
  class All
    def initialize(pull_requests: [], input: Input.instance)
      @input = input
    end

    def pull_requests
      @pull_requests ||= Octokit.pulls(input.source.repo, pull_options).map do |pr|
        PullRequest.new(pr: pr) # keep this lazy, specific filters should pull data if they need to
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
