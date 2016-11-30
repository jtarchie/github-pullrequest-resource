require 'octokit'

class PullRequest
  def self.from_github(repo:, id:)
    pr = Octokit.pull_request(repo.name, id)
    PullRequest.new(pr: pr)
  end

  def initialize(pr:)
    @pr = pr
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
end
