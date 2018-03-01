# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'check' do
  def check(payload)
    path = ['./assets/check', '/opt/resource/check'].find { |p| File.exist? p }
    payload[:source][:skip_ssl_verification] = true

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path}`
    JSON.parse(output)
  end

  let(:proxy) { Billy::Proxy.new }

  before { proxy.start }
  after  { proxy.reset }

  context 'when working with an external API' do
    it 'makes requests with respect to that endpoint' do
      proxy.stub('https://test.example.com:443/repos/jtarchie/test/pulls')
           .and_return(json: [])

      expect(check(source: {
                     repo: 'jtarchie/test',
                     api_endpoint: 'https://test.example.com'
                   })).to eq []
    end
  end
end
