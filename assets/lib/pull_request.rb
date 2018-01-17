require 'octokit'

class PullRequest
  def self.from_github(repo:, id:)
    pr = Octokit.pull_request(repo.name, id)
    tc = Octokit.commit(repo.name, pr['head']['sha'])
    PullRequest.new(pr: pr, top_commit: tc)
  end

  def initialize(pr:, top_commit:)
    @pr = pr
    @top_commit = top_commit
  end

  def from_fork?
    base_repo != head_repo
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

  def latest_commit_message
    @top_commit['commit']['message']
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
