require 'octokit'
require_relative 'pull_request'

class Repository
  attr_reader :name

  def initialize(name:)
    @name = name
  end

  def pull_requests(args = {})
    @pull_requests ||= Octokit.pulls(name, pulls_options(args)).map do |pr|
      PullRequest.new(repo: self, pr: pr)
    end
  end

  def pull_request(id:)
    pr = Octokit.pull_request(name, id)
    PullRequest.new(repo: self, pr: pr)
  end

  def next_pull_request(id: nil, sha: nil, base: nil)
    return if pull_requests(base: base).empty?

    if id && sha
      current = pull_requests.find { |pr| pr.equals?(id: id, sha: sha) }
      return if current && current.ready?
    end

    pull_requests.find do |pr|
      pr != current && pr.ready?
    end
  end

  def pull_request_matches_paths?(id, paths)
    files = Octokit.pull_request_files(name, id)
    files.map do |file|
      if File.fnmatch(paths, file['filename'])
        return true
      end
    end
    false
  end

  private

  def pulls_options(base: nil)
    base ? default_opts.merge(base: base) : default_opts
  end

  def default_opts
    { state: 'open', sort: 'updated', direction: 'asc' }
  end
end
