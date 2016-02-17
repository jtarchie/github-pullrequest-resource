# encoding: utf-8
require 'octokit'
require 'fileutils'

class Status
  def initialize(state:, atc_url:, sha:, repo:, context: 'concourseci')
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
      context: 'concourseci',
      description: "Concourse CI build #{@state}",
      target_url: target_url
    )
  end

  private

  def target_url
    "#{@atc_url}/builds/#{ENV['BUILD_ID']}" if @atc_url
  end
end

class PullRequest
  def initialize(repo:, pr:)
    @repo = repo
    @pr = pr
  end

  def ready?
    statuses.empty?
  end

  def equals?(id:, sha:)
    [self.sha, self.id.to_s] == [sha, id.to_s]
  end

  def as_json
    { ref: sha, pr: id.to_s }
  end

  def id
    @pr['number']
  end

  def sha
    @pr['head']['sha']
  end

  def url
    @pr['url']
  end

  private

  def statuses
    @statuses ||= Octokit.statuses(@repo.name, sha).select do |status|
      status['context'] == 'concourseci'
    end
  end
end

class Repository
  attr_reader :name

  def initialize(name:)
    @name = name
  end

  def pull_requests
    @pull_requests ||= Octokit.pulls(name, state: 'open', sort: 'updated', direction: 'desc').map do |pr|
      PullRequest.new(repo: self, pr: pr)
    end
  end

  def pull_request(id:)
    pr = Octokit.pull_request(name, id)
    PullRequest.new(repo: self, pr: pr)
  end

  def next_pull_request(id: nil, sha: nil)
    return if pull_requests.empty?

    if id && sha
      current = pull_requests.find { |pr| pr.equals?(id: id, sha: sha) }
      return if current && current.ready?
    end

    pull_requests.find do |pr|
      pr != current && pr.ready?
    end
  end
end

def input
  @input ||= JSON.parse(ARGF.read)
end

def json!(payload)
  puts JSON.generate(payload)
  exit
end

Octokit.auto_paginate = true
Octokit.connection_options[:ssl] = { verify: false } if input['source']['no_ssl_verify']
Octokit.configure do |c|
  c.api_endpoint = input['source']['api_endpoint'] if input['source']['api_endpoint']
  c.access_token = input['source']['access_token']
end
