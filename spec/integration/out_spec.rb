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

  context 'when the git repo has the pull request meta information' do
    before do
      git('config --add pullrequest.id 1')
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
           .and_return(json: {
                         html_url: 'http://example.com',
                         number: 1,
                         head: { sha: 'abcdef' }
                       })
    end

    context 'when setting a status with a comment' do
      before do
        File.write(File.join(dest_dir, 'comment'), 'comment message')
      end

      it 'posts a comment to the PR\'s SHA' do
        proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/issues/1/comments', method: :post)
             .and_return(json: { id: 1 })

        output, = put(params: { status: 'success', path: 'resource', comment: 'resource/comment' }, source: { repo: 'jtarchie/test' })
        expect(output).to eq('version'  => { 'ref' => @sha, 'pr' => '1' },
                             'metadata' => [
                               { 'name' => 'status', 'value' => 'success' },
                               { 'name' => 'url', 'value' => 'http://example.com' }
                             ])
      end

      context 'when the message file does not exist' do
        it 'returns a helpful error message' do
          _, error = put(params: { status: 'success', path: 'resource', comment: 'resource/comment-doesnt-exist' }, source: { repo: 'jtarchie/test' })

          expect(error).to include '`comment` "resource/comment-doesnt-exist" does not exist'
        end
      end
    end

    context 'when acquiring a pull request' do
      it 'sets into pending mode' do
        proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

        output, error = put(params: { status: 'pending', path: 'resource' }, source: { repo: 'jtarchie/test' })
        expect(output).to eq('version'  => { 'ref' => @sha, 'pr' => '1' },
                             'metadata' => [
                               { 'name' => 'status', 'value' => 'pending' },
                               { 'name' => 'url', 'value' => 'http://example.com' }
                             ])
      end

      context 'with bad params' do
        it 'raises an error when path is missing' do
          _, error = put(params: { status: 'pending' }, source: { repo: 'jtarchie/test' })
          expect(error).to include '`path` required in `params`'
        end

        it 'raises an error when the path does not exist' do
          _, error = put(params: { status: 'pending', path: 'do not care' }, source: { repo: 'jtarchie/test' })
          expect(error).to include '`path` "do not care" does not exist'
        end

        context 'with unsupported statuses' do
          it 'raises an error the supported ones' do
            _, error = put(params: { status: 'do not care', path: 'resource' }, source: { repo: 'jtarchie/test' })
            expect(error).to include '`status` "do not care" is not supported -- only success, failure, error, or pending'
          end
        end
      end
    end

    context 'when the pull request is being release' do
      context 'and the build passed' do
        it 'sets into success mode' do
          proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

          output, = put(params: { status: 'success', path: 'resource' }, source: { repo: 'jtarchie/test' })
          expect(output).to eq('version'  => { 'ref' => @sha, 'pr' => '1' },
                               'metadata' => [
                                 { 'name' => 'status', 'value' => 'success' },
                                 { 'name' => 'url', 'value' => 'http://example.com' }
                               ])
        end

        context 'with base_url defined on source' do
          it 'sets the target_url for status' do
            proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

            put(params: { status: 'success', path: 'resource' }, source: { repo: 'jtarchie/test', base_url: 'http://example.com' })

            body = request_body('post', "https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}")
            expect(JSON.parse(body)).to include('target_url' => 'http://example.com/builds/1234')
          end
        end

        context 'with no base_url defined, but with ATC_EXTERNAL_URL defined' do
          it 'sets the target_url for status' do
            ENV['ATC_EXTERNAL_URL'] = 'http://atc-endpoint.com'
            proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

            put(params: { status: 'success', path: 'resource' }, source: { repo: 'jtarchie/test' })

            body = request_body('post', "https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}")
            expect(JSON.parse(body)).to include('target_url' => 'http://atc-endpoint.com/builds/1234')
          end
        end

        it 'sets the a default context on the status' do
          proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

          put(params: { status: 'success', path: 'resource' }, source: { repo: 'jtarchie/test' })

          body = request_body('post', "https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}")
          expect(JSON.parse(body)).to include('context' => 'concourse-ci/status')
        end

        context 'with a custom context for the status' do
          it 'sets the context' do
            proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

            put(params: { status: 'success', path: 'resource', context: 'my-custom-context' }, source: { repo: 'jtarchie/test' })

            body = request_body('post', "https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}")
            expect(JSON.parse(body)).to include('context' => 'concourse-ci/my-custom-context')
          end
        end
      end

      context 'and the build failed' do
        it 'sets into failure mode' do
          proxy.stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@sha}", method: :post)

          output, = put(params: { status: 'failure', path: 'resource' }, source: { repo: 'jtarchie/test' })
          expect(output).to eq('version'  => { 'ref' => @sha, 'pr' => '1' },
                               'metadata' => [
                                 { 'name' => 'status', 'value' => 'failure' },
                                 { 'name' => 'url', 'value' => 'http://example.com' }
                               ])
        end
      end
    end
  end
end
