require 'octokit'

class Status
  def initialize(state:, atc_url:, sha:, repo:, title:, description:, context: 'concourse-ci')
    @atc_url = atc_url
    @context = context
    @repo    = repo
    @sha     = sha
    @state   = state
    @title   = title.nil? ? 'concourse-ci' : title
    @description = description.nil? ? "Concourse CI build #{@state}" : description
  end

  def create!
    Octokit.create_status(
      @repo.name,
      @sha,
      @state,
      context: "#{@title}/#{@context}",
      description: @description,
      target_url: target_url
    )
  end

  private

  def target_url
    "#{@atc_url}/builds/#{ENV['BUILD_ID']}" if @atc_url
  end
end
