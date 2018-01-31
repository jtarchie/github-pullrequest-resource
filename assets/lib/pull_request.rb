# frozen_string_literal: true

require 'octokit'

class PullRequest
  def self.from_github(repo:, id:)
    pr = Octokit.pull_request(repo.name, id)
    PullRequest.new(pr: pr)
  end

  def initialize(pr:)
    @pr = pr
  end

  def from_fork?
    base_repo != head_repo
  end

  def mergeable?
      (@pr['mergeable'] &&
       @pr['base']['repo']['permissions']['push'] &&
       Octokit.pull_request_reviews(base_repo, id).any? {|r| r['state'] == 'APPROVED'})
  end

  def equals?(id:, sha:)
    [self.sha, self.id.to_s] == [sha, id.to_s]
  end

  def to_json(*)
    as_json.to_json
  end

  def as_json
    { 'ref' => sha, 'pr' => id.to_s }
  end

  def id
    @pr['number']
  end

  def sha
    @pr['head']['sha']
  end

  def url
    @pr['html_url']
  end

  private

  def base_repo
    @pr['base']['repo']['full_name']
  end

  def head_repo
    @pr['head']['repo']['full_name']
  end
end
