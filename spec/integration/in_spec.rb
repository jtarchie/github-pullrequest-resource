# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tmpdir'

describe 'get' do
  include CliIntegration

  let(:proxy) { Billy::Proxy.new }
  let(:dest_dir) { Dir.mktmpdir }
  let(:git_dir)  { Dir.mktmpdir }
  let(:git_uri)  { "file://#{git_dir}" }

  before { proxy.start }
  after  { proxy.reset }

  def git(cmd, dir = git_dir)
    Dir.chdir(dir) { `git #{cmd}`.chomp }
  end

  def commit(msg)
    git("-c user.name='test' -c user.email='test@example.com' commit -q --allow-empty -m '#{msg}'")
    git('log --format=format:%H HEAD')
  end

  before do
    git('init -q')
    `rm -Rf #{git_dir}/.git/hooks`
    @ref = commit('init')
    commit('second')

    git("update-ref refs/pull/1/head #{@ref}")
    git("update-ref refs/pull/1/merge #{@ref}")
  end

  context 'for every PR that is checked out' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
           .and_return(json: { html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' } })
    end

    it 'checks out the pull request to dest_dir' do
      get(version: { ref: @ref, pr: '1' }, source: { access_token: 'abc', uri: git_uri, repo: 'jtarchie/test' })
      expect(@ref).to eq git('log --format=format:%H HEAD', dest_dir)
    end
  end
end
