# frozen_string_literal: true

module Filters
  class Approval
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.require_review_approval
        @pull_requests.delete_if { |x| !x.review_approved? }
      end
      if @input.source.authorship_restriction
        @pull_requests.delete_if { |x| !x.author_associated? }
      end

      @pull_requests
    end
  end
end
