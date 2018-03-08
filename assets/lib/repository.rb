# frozen_string_literal: true

require_relative 'filters/all'
require_relative 'filters/fork'
require_relative 'filters/label'
require_relative 'filters/path'
require_relative 'filters/ci_skip'
require_relative 'filters/mergeable'
require_relative 'filters/approval'

class Repository
  attr_reader :name

  def initialize(name:, input: Input.instance, filters: [Filters::All, Filters::Path, Filters::Fork, Filters::Label, Filters::CISkip, Filters::Mergeable, Filters::Approval])
    @filters = filters
    @name    = name
    @input   = input
  end

  def pull_requests(_args = {})
    @pull_requests ||= @filters.reduce([]) do |pull_requests, filter|
      filter.new(pull_requests: pull_requests).pull_requests
    end
  end
end
