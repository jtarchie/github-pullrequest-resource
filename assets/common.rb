require 'octokit'
require 'fileutils'

Octokit.auto_paginate = true
Octokit.connection_options[:ssl] = { verify: false } if ENV['http_proxy']

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

  def status!(state)
    Octokit.create_status(
      @repo.name,
      sha,
      state
    )
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

def load_key(input)
  private_key      = input['source']['private_key'] || ""
  private_key_path = '/tmp/private_key'

  File.write(private_key_path, private_key)

  unless File.zero?(private_key_path)
    FileUtils.chmod(0600, private_key_path)
    system <<-SHELL
      $(ssh-agent) >/dev/null 2>&1
      trap "kill $SSH_AGENT_PID" 0
      SSH_ASKPASS=/opt/resource/askpass.sh DISPLAY= ssh-add $private_key_path >/dev/null
    SHELL

    FileUtils.mkdir_p('~/.ssh')
    File.write('~/.ssh/config', <<-SSHCONFIG)
StrictHostKeyChecking no
LogLevel quiet
EOF
    SSHCONFIG
    FileUtils.chmod(0600, '~/.ssh/config')
  end
end
