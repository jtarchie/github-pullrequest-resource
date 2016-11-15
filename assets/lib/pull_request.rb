require 'octokit'

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

  def to_json(*)
    { ref: sha, pr: id.to_s }.to_json
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

  def statuses
    @statuses ||= Octokit.statuses(@repo.name, sha).select do |status|
      status['context'] =~ /^concourse-ci/
    end
  end
end
