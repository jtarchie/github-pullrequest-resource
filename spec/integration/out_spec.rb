# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

describe 'out' do
  include CliIntegration

  let(:proxy) { Billy::Proxy.new }
  let(:dest_dir) { Dir.mktmpdir }

  before { proxy.start }
  after  { proxy.reset }

  def git(cmd, dir = dest_dir)
    Dir.chdir(dir) { `git #{cmd}`.chomp }
  end

  def commit(msg)
    git("-c user.name='test' -c user.email='test@example.com' commit -q --allow-empty -m '#{msg}'")
    git('log --format=format:%H HEAD')
  end

  def request_body(method, url)
    response = Billy::Cache.instance.fetch(
      method.to_s,
      url.to_s,
      ''
    )
    response[:body]
  end

  before do
    git('init -q')

    @sha = commit('test commit')

    proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}")
         .and_return(json: [])
    ENV['BUILD_ID'] = '1234'
  end

  context 'when the git repo has no pull request meta information' do
    it 'sets the status just on the SHA' do
      proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

      output, error = put(params: { status: 'pending', path: 'resource' }, source: { repo: 'jtarchie/test' })
      expect(output).to eq('version'  => { 'ref' => @sha },
                           'metadata' => [
                             { 'name' => 'status', 'value' => 'pending' }
                           ])
    end
  end
end
