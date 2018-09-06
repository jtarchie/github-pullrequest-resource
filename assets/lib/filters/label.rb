# frozen_string_literal: true

module Filters
  class Label
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.no_label
        @pull_requests = @pull_requests.reject do |pr|
          issue = Octokit.issue(@input.source.repo, pr.id)
          labels = issue[:labels] || []
          labels.find { |l| l['name'].to_s.casecmp(@input.source.no_label.to_s.downcase).zero? }
        end
      end
      if @input.source.label
        @pull_requests = @pull_requests.select do |pr|
          issue  = Octokit.issue(@input.source.repo, pr.id)
          labels = issue[:labels] || []
          labels.find { |l| l['name'].to_s.casecmp(@input.source.label.to_s.downcase).zero? }
        end
      end
      @pull_requests
    end
  end
end
