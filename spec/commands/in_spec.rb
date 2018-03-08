# frozen_string_literal: true

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
    payload['source']['skip_ssl_verification'] = true
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
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com',
                  number: 1,
                  head: {
                    ref: 'foo',
                    sha: 'hash'
                  },
                  base: {
                    ref: 'master',
                    sha: 'basehash',
                    user: {
                      login: 'jtarchie'
                    }
                  },
                  body: %(A comment with shell stuff var='\'`rm -rf ./*`\''),
                  user: {
                    login: 'jtarchie-contributor'
                  })
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

      it 'sets config of the PR body' do
        value = git('config --get pullrequest.body', dest_dir)
        expect(value).to eq "A comment with shell stuff var=''`rm -rf ./*`''"
      end

      it 'sets config variable to branch name' do
        value = git('config pullrequest.branch', dest_dir)
        expect(value).to eq 'foo'
      end

      it 'sets config variable to base_branch name' do
        value = git('config pullrequest.basebranch', dest_dir)
        expect(value).to eq 'master'
      end

      it 'sets config variable to basesha name' do
        value = git('config pullrequest.basesha', dest_dir)
        expect(value).to eq 'basehash'
      end

      it 'sets config variable to user_login name' do
        value = git('config pullrequest.userlogin', dest_dir)
        expect(value).to eq 'jtarchie-contributor'
      end

      it 'creates a file that icludes the id in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'id')).strip
        expect(value).to eq '1'
      end

      it 'creates a file that icludes the url in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'url')).strip
        expect(value).to eq 'http://example.com'
      end

      it 'creates a file that icludes ahe branch in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'branch')).strip
        expect(value).to eq 'foo'
      end

      it 'creates a file that icludes the base_branch in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'base_branch')).strip
        expect(value).to eq 'master'
      end

      it 'creates a file that icludes the base_sha in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'base_sha')).strip
        expect(value).to eq 'basehash'
      end

      it 'creates a file that includes the hash of the branch  in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'head_sha')).strip
        expect(value).to eq 'hash'
      end

      it 'creates a file that contains the PR body in the .git folder' do
        value = File.read(File.join(dest_dir, '.git', 'body')).strip
        expect(value).to eq "A comment with shell stuff var=''`rm -rf ./*`''"
      end
    end

    context 'when the git clone fails' do
      it 'provides a helpful erorr message' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1', html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' })

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => 'invalid_git_uri', 'repo' => 'jtarchie/test' })
        end.to raise_error('git clone failed')
      end
    end
  end

  context 'when the PR is meregable' do
    context 'and fetch_merge is false' do
      it 'checks out as a branch named in the PR' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' }, mergeable: true)

        get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => false })

        value = git('rev-parse --abbrev-ref HEAD', dest_dir)
        expect(value).to eq 'pr-foo'
      end

      it 'does not fail cloning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' }, mergeable: true)

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => false })
        end.not_to output(/git clone failed/).to_stderr
      end
    end

    context 'and fetch_merge is true' do
      it 'checks out the branch the PR would be merged into' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' }, mergeable: true)

        get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params:' => { 'fetch_merge' => true })

        value = git('rev-parse --abbrev-ref HEAD', dest_dir)
        expect(value).to eq 'pr-foo'
      end

      it 'does not fail cloning' do
        stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' }, mergeable: true)

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
                  html_url: 'http://example.com', number: 1, head: { ref: 'foo' }, base: { ref: 'master', user: { login: 'jtarchie' } }, user: { login: 'jtarchie-contributor' }, mergeable: false)

        expect do
          get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'fetch_merge' => true })
        end.to raise_error('PR has merge conflicts')
      end
    end
  end

  fcontext 'with specific `git` params' do
    before do
      stub_json('https://api.github.com:443/repos/jtarchie/test/pulls/1',
                html_url: 'http://example.com', number: 1,
                head: { ref: 'foo' },
                base: { ref: 'master', user: { login: 'jtarchie' } },
                user: { login: 'jtarchie-contributor' })
    end

    def expect_arg(*args)
      allow_any_instance_of(Commands::In).to receive(:system).and_call_original
      expect_any_instance_of(Commands::In).to receive(:system).with(*args).and_call_original
    end

    def dont_expect_arg(*args)
      allow_any_instance_of(Commands::In).to receive(:system).and_call_original
      expect_any_instance_of(Commands::In).not_to receive(:system).with(*args).and_call_original
    end

    it 'gets lfs' do
      expect_arg /git lfs fetch/
      expect_arg /git lfs checkout/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => {})
    end

    it 'disables lfs' do
      dont_expect_arg /git lfs fetch/
      dont_expect_arg /git lfs checkout/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'git' => { 'disable_lfs' => true } })
    end

    it 'gets all the submodules' do
      expect_arg /git submodule update --init --recursive/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => {})
    end

    it 'gets all the submodules explicitly' do
      expect_arg /git submodule update --init --recursive/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'git' => { 'submodules' => 'all' } })
    end

    it 'gets no submodules' do
      dont_expect_arg /git submodule update --init --recursive/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'git' => { 'submodules' => 'none' } })
    end

    it 'get submodules with paths' do
      expect_arg /git submodule update --init --recursive  path1/
      expect_arg /git submodule update --init --recursive  path2/
      get('version' => { 'ref' => @ref, 'pr' => '1' }, 'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' }, 'params' => { 'git' => { 'submodules' => %w[path1 path2] } })
    end

    it 'checkouts everything by depth' do
      expect_arg /git submodule update --init --recursive --depth 100 path1/
      expect_arg /git clone --depth 100 --branch master/
      expect_arg /git fetch --depth 100/
      get('version' => { 'ref' => @ref, 'pr' => '1' },
          'source' => { 'uri' => git_uri, 'repo' => 'jtarchie/test' },
          'params' => {
            'git' => {
              'submodules' => %w[path1 path2],
              'depth' => 100
            }
          })
    end
  end
end
