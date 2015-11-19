require 'spec_helper'
require 'json'

describe 'check' do
  let(:proxy) { Billy::Proxy.new }

  before { proxy.start }
  after  { proxy.reset }

  context 'when there are no pull requests' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [])
    end

    it 'returns no versions' do
      expect(check(source: { repo: 'jtarchie/test'})).to eq []
    end

    context 'when there is a last known version' do
      it 'returns no versions' do
        payload = { version: { ref: '1' }, source: { repo: 'jtarchie/test' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
          .and_return(json: {})

        expect(check(payload)).to eq []
      end
    end
  end

  context 'when there is an open pull request' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [{ number: 1, head: { sha: 'abcdef' } }])
    end

    context 'that has no status' do
      before do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [])
      end

      it 'returns SHA of the pull request' do
        expect(check(source: { repo: 'jtarchie/test' }, version: {})).to eq [{ 'ref' => 'abcdef', 'pr' => '1' }]
      end

      context 'and the version is the same as the pull request' do
        it 'returns nothing' do
          payload = { version: { ref: 'abcdef', pr: '1' }, source: { repo: 'jtarchie/test' } }

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
        expect(check(source: { repo: 'jtarchie/test' }, version: {})).to eq []
      end

      context 'and the version is the same as the pull request' do
        it 'returns nothing' do
          payload = { version: { ref: 'abcdef', pr: '1' }, source: { repo: 'jtarchie/test' } }

          expect(check(payload)).to eq []
        end
      end
    end

    context 'that has another status' do
      it 'does not return it' do
        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [
            { state: 'pending', context: 'concourseci' },
            { state: 'success', context: 'concourseci' }
          ])

        expect(check(source: { repo: 'jtarchie/test' }, version: {})).to eq []
      end
    end
  end

  context 'when there is more than one open pull request' do
    before do
      proxy.stub('https://api.github.com:443/repos/jtarchie/test/pulls')
        .and_return(json: [
          { number: 2, head: { sha: 'zyxwvu' } },
          { number: 1, head: { sha: 'abcdef' } }
        ])
    end

    context 'and the version is the same as the older pull request' do
      it 'returns the latest pull request when the current version is not pending' do
        payload = { version: { ref: 'abcdef', pr: '1' }, source: { repo: 'jtarchie/test' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'pending', context: 'concourseci' }])

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/zyxwvu')
          .and_return(json: [])

        expect(check(payload)).to eq [{ 'ref' => 'zyxwvu', 'pr' => '2' }]
      end

      it 'returns nothing when its still pending' do
        payload = { version: { ref: 'abcdef', pr: '1' }, source: { repo: 'jtarchie/test' } }

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/abcdef')
          .and_return(json: [{ state: 'success', context: 'concourseci' }])

        proxy.stub('https://api.github.com:443/repos/jtarchie/test/statuses/zyxwvu')
          .and_return(json: [{ state: 'pending', context: 'concourseci' }])

        expect(check(payload)).to eq []
      end
    end
  end
end
