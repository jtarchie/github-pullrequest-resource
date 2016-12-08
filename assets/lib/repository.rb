require_relative 'filters/all'
require_relative 'filters/context'
require_relative 'filters/fork'

class Repository
  attr_reader :name

  def initialize(name:, input: Input.instance, filters: [Filters::All, Filters::Fork, Filters::Context])
    @filters = filters
    @name    = name
    @input   = input
  end

  def pull_requests(_args = {})
    @pull_requests ||= @filters.reduce([]) do |pull_requests, filter|
      filter.new(pull_requests: pull_requests).pull_requests
    end
  end

  def next_pull_request(id: nil, sha: nil)
    return if pull_requests.empty?

    if id && sha
      current = pull_requests.find { |pr| pr.equals?(id: id, sha: sha) }
      return if current
    end

    pull_requests.find do |pr|
      pr != current
    end
  end
end
