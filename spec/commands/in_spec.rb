require 'json'
require 'tmpdir'
require 'webmock/rspec'
require_relative '../../assets/lib/commands/in'

describe Commands::In do
  def git_dir
    @git_dir ||= Dir.mktmpdir
  end

  def git_uri
    "file://#{git_dir}"
  end

  let(:dest_dir) { Dir.mktmpdir }

  def get(payload)
    payload['source']['no_ssl_verify'] = true
    Input.instance(payload: payload)
    command = Commands::In.new(destination: dest_dir)
    command.output
  end

  def stub_json(uri, body)
    stub_request(:get, uri)
      .to_return(headers: { 'Content-Type' => 'application/json' }, body: body.to_json)
  end

  def git(cmd, dir = git_dir)
    Dir.chdir(dir) { `git #{cmd}`.chomp }
  end

  def commit(msg)
    git("-c user.name='test' -c user.email='test@example.com' commit -q --allow-empty -m '#{msg}'")
    git('log --format=format:%H HEAD')
  end

  before(:all) do
    git('init -q')

    @ref = commit('init')
    commit('second')

    git("update-ref refs/pull/1/head #{@ref}")
    git("update-ref refs/pull/1/merge #{@ref}")
  end

  context 'for every PR that is checked out' do
    context 'with meta information attached to the git repo' do
      def dest_dir
        @dest_dir ||= Dir.mktmpdir
      end

      before(:all) do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1', html_url: 'http://example.com', number: 1, head: { ref: 'foo' })
        @output = get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' })
      end

      it 'checks out the pull request to dest_dir' do
        expect(@ref).to eq git('log --format=format:%H HEAD', dest_dir)
      end

      it 'returns the correct JSON metadata' do
        expect(@output).to eq('version' => { 'ref' => @ref, 'pr' => '1' },
                              'metadata' => [{
                                'name' => 'url',
                                'value' => 'http://example.com'
                              }])
      end

      it 'adds metadata to `git config`' do
        value = git('config --get pullrequest.url', dest_dir)
        expect(value).to eq 'http://example.com'
      end

      it 'checks out as a branch with a `pr-` prefix' do
        value = git('rev-parse --abbrev-ref HEAD', dest_dir)
        expect(value).to eq 'pr-foo'
      end

      it 'sets config variable to branch name' do
        value = git('config pullrequest.branch', dest_dir)
        expect(value).to eq 'foo'
      end
    end

    context 'when the git clone fails' do
      it 'provides a helpful erorr message' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1', html_url: 'http://example.com', number: 1, head: { ref: 'foo' })

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => 'invalid_git_uri', 'repo' => 'jtarchie/test' })
        end.to raise_error('git clone failed')
      end
    end

    context 'when `every` is not defined' do
      it 'skips the deprecation warning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1', html_url: 'http://example.com', number: 1, head: { ref: 'foo' })

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' })
        end.to output("DEPRECATION: Please note that you should update to using `version: every` on your `get` for this resource.\n").to_stderr
      end
    end

    context 'when `every` is defined' do
      it 'shows a deprecation warning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1', html_url: 'http://example.com', number: 1, head: { ref: 'foo' })

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test', 'every' => true })
        end.not_to output("DEPRECATION: Please note that you should update to using `version: every` on your `get` for this resource.\n").to_stderr
      end
    end
  end

  context 'when the PR is meregable' do
    context 'and fetch_merge is false' do
      it 'checks out as a branch named in the PR' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, mergeable: true)

        get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => false })

        value = git('rev-parse --abbrev-ref HEAD', dest_dir)
        expect(value).to eq 'pr-foo'
      end

      it 'does not fail cloning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, mergeable: true)

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => false })
        end.not_to output(/git clone failed/).to_stderr
      end
    end

    context 'and fetch_merge is true' do
      it 'checks out the branch the PR would be merged into' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, mergeable: true)

        get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params:' => { 'fetch_merge' => true })

        value = git('rev-parse --abbrev-ref HEAD', dest_dir)
        expect(value).to eq 'pr-foo'
      end

      it 'does not fail cloning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, mergeable: true)

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => true })
        end.not_to output(/git clone failed/).to_stderr
      end
    end
  end

  context 'when the PR is not mergeable' do
    context 'and fetch_merge is true' do
      it 'raises a helpful error message' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, mergeable: false)

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => true })
        end.to raise_error('PR has merge conflicts')
      end
    end
  end
end
