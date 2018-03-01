# frozen_string_literal: true

require 'open3'

module CliIntegration
  def check(payload)
    path = ['./assets/check', '/opt/resource/check'].find { |p| File.exist? p }
    payload[:source][:skip_ssl_verification] = true

    output = `echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path}`
    JSON.parse(output)
  end

  def get(payload = {})
    path = ['./assets/in', '/opt/resource/in'].find { |p| File.exist? p }
    payload[:source][:skip_ssl_verification] = true

    output, error, = Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{dest_dir}")

    response = begin
                 JSON.parse(output)
               rescue StandardError
                 nil
               end
    [response, error]
  end

  def put(payload = {})
    path = ['./assets/out', '/opt/resource/out'].find { |p| File.exist? p }
    payload[:source][:skip_ssl_verification] = true

    resource_dir = Dir.mktmpdir
    FileUtils.cp_r(dest_dir, File.join(resource_dir, 'resource'))

    output, error, = Open3.capture3("echo '#{JSON.generate(payload)}' | env http_proxy=#{proxy.url} #{path} #{resource_dir}")

    response = begin
                 JSON.parse(output)
               rescue StandardError
                 nil
               end
    [response, error]
  end
end
