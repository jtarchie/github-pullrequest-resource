# frozen_string_literal: true

require 'octokit'

class Status
  def initialize(state:, atc_url:, sha:, repo:, context: 'concourse-ci')
    @atc_url = atc_url
    @context = context
    @repo    = repo
    @sha     = sha
    @state   = state
  end

  def create!
    Octokit.create_status(
      @repo.name,
      @sha,
      @state,
      context: "concourse-ci/#{@context}",
      description: "Concourse CI build #{@state}",
      target_url: target_url
    )
  end

  private

  def target_url
    "#{@atc_url}/builds/#{ENV['BUILD_ID']}" if @atc_url
  end
end
