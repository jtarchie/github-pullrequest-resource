require 'octokit'
require_relative '../pull_request'

module Filters
  class All
    def initialize(pull_requests: [], input: Input.instance)
      @input = input
    end

    def pull_requests

      if File.file?('etag.txt')
        Octokit.connection_options[:headers]['If-None-Match'] = File.open('etag.txt', "rb").read
      end

      pulls = Octokit.pulls(input.source.repo, pull_options)

      File.open('etag.txt', 'w') { |file| file.write(Octokit.last_response.headers[:etag]) }

      if pulls == ""
        pulls = JSON.load(File.open('pulls.json', "rb").read)
      else
        File.open('pulls.json', 'w') { |file| file.write(pulls.map(&:to_h).to_json) }
      end

      @pull_requests ||= pulls.map do |pr|
        PullRequest.new(pr: pr)
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
