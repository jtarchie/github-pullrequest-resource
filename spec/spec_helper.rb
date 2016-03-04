# encoding: utf-8
require 'billy'
require 'open3'

Billy.configure do |c|
  c.cache = true
  c.merge_cached_responses_whitelist = [/github/]
  c.non_successful_error_level = :error
  c.non_whitelisted_requests_disabled = true
end

module StubCacheHandler
  def handle_request(method, url, headers, body)
    if response = super
      Billy::Cache.instance.store(method.downcase, url, headers, body, response[:headers], response[:status], response[:content])
      return response
    end
  end
end

Billy::StubHandler.prepend(StubCacheHandler)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

def check(payload)
  path = ['./assets/check', '/opt/resource/check'].find { |p| File.exist? p }
  payload[:source][:no_ssl_verify] = true

  output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path}`
  JSON.parse(output)
end

def get(payload = {})
  path = ['./assets/in', '/opt/resource/in'].find { |p| File.exist? p }
  payload[:source][:no_ssl_verify] = true

  output, error, = with_resource do |_dir|
    Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dest_dir}")
  end
  [(begin
      JSON.parse(output)
    rescue
      nil
    end), error]
end

def put(payload = {})
  path = ['./assets/out', '/opt/resource/out'].find { |p| File.exist? p }
  payload[:source][:no_ssl_verify] = true

  output, error, = with_resource do |dir|
    Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dir}")
  end

  [(begin
      JSON.parse(output)
    rescue
      nil
    end), error]
end

def with_resource
  tmp_dir = Dir.mktmpdir
  FileUtils.cp_r(dest_dir, File.join(tmp_dir, 'resource'))
  yield(tmp_dir)
end
