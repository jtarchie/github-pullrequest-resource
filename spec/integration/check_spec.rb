require 'spec_helper'
require 'json'
require 'billy'

describe 'check' do
  let(:proxy) { Billy::Proxy.new }

  before { proxy.start }
  after  { proxy.reset }

  def check(payload = {})
    path = ['./assets/check', '/opt/resource/check'].find { |p| File.exist? p }
    payload[:source] = { repo: 'jtarchie/test' }

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path}`
    JSON.parse(output)
  end

  context 'when there are no pull requests' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [])
    end

    it 'returns no versions' do
      expect(check).to eq []
    end

    context 'when there is a last known version' do
      it 'returns no versions' do
        payload = { version: { ref: '1' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
          .and_return(json: {})

        expect(check(payload)).to eq []
      end
    end
  end

  context 'when there is an open pull request' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [{ id: '1', head: { sha: 'abcdef' } }])
    end

    context 'that has no status' do
      before do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [])
      end

      it 'returns SHA of the pull request' do
        expect(check).to eq [{ 'ref' => 'abcdef', 'pr' => '1' }]
      end

      context 'and the version is the same as the pull request' do
        it 'returns nothing' do
          payload = { version: { ref: 'abcdef', pr: '1' } }

          expect(check(payload)).to eq []
        end
      end
    end

    context 'that has a pending status' do
      before do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'pending', context: 'concourseci' }])
      end

      it 'returns SHA of the pull request' do
        expect(check).to eq [{ 'ref' => 'abcdef', 'pr' => '1' }]
      end

      context 'and the version is the same as the pull request' do
        it 'returns nothing' do
          payload = { version: { ref: 'abcdef', pr: '1' } }

          expect(check(payload)).to eq []
        end
      end
    end

    context 'that has another status' do
      it 'does not return it' do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'success', context: 'concourseci' }])

        expect(check).to eq []
      end
    end
  end

  context 'when there is more than one open pull request' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [
          { id: '2', head: { sha: 'zyxwvu' } },
          { id: '1', head: { sha: 'abcdef' } }
        ])
    end

    context 'and the version is the same as the older pull request' do
      it 'returns nothing when its still pending' do
        payload = { version: { ref: 'abcdef', pr: '1' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'pending', context: 'concourseci' }])

        expect(check(payload)).to eq []
      end

      it 'returns the latest pull request when the current version is not pending' do
        payload = { version: { ref: 'abcdef', pr: '1' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'success', context: 'concourseci' }])

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/zyxwvu')
          .and_return(json: [{ state: 'pending', context: 'concourseci' }])

        expect(check(payload)).to eq [{ 'ref' => 'zyxwvu', 'pr' => '2' }]
      end
    end
  end
end
