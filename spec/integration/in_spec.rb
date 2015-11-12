require 'spec_helper'
require 'json'
require 'tmpdir'
require 'billy'

describe 'get' do
  let(:proxy) { Billy::Proxy.new }
  let(:dest_dir) { Dir.mktmpdir }
  let(:git_dir)  { Dir.mktmpdir }
  let(:git_uri)  { "file://#{git_dir}" }

  before { proxy.start }
  after  { proxy.reset }

  def get(payload = {})
    path = ['./assets/in', '/opt/resource/in'].find { |p| File.exist? p }
    payload[:source][:repo] = 'jtarchie/test'

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dest_dir}`
    JSON.parse(output)
  end

  def git(cmd, dir = git_dir)
    Dir.chdir(dir) { `git #{cmd}`.chomp }
  end

  before do
    proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
      .and_return(json: { url: 'http://example.com' })

    git('init -q')
    git("-c user.name='test' -c user.email='test@example.com' commit -q --allow-empty -m 'init'")
  end

  it 'checks out the pull request to dest_dir' do
    ref = git('log --format=format:%H HEAD')
    get(version: { ref: ref, pr: '1' }, source: { uri: git_uri })
    expect(ref).to eq git('log --format=format:%H HEAD', dest_dir)
  end

  it 'returns the correct JSON metadata' do
    ref = git('log --format=format:%H HEAD')
    output = get(version: { ref: ref, pr: '1' }, source: { uri: git_uri })
    expect(output).to eq('version'  => { 'ref' => ref, 'pr' => '1' },
                         'metadata' => { 'url' => 'http://example.com' })
  end

  it 'adds metadata to `git config`' do
    ref = git('log --format=format:%H HEAD')
    get(version: { ref: ref, pr: '1' }, source: { uri: git_uri })

    value = git('config --get pullrequest.url', dest_dir)
    expect(value).to eq 'http://example.com'
  end
end
