require 'json'
require 'ostruct'

class Input
  def self.instance(payload: nil)
    @instance = new(payload: payload) if payload
    @instance ||= begin
                    payload = JSON.parse(ARGF.read)
                    new(payload: payload)
                  end
  end

  def self.reset
    @instance = nil
  end

  def initialize(payload:)
    @payload = payload
  end

  def source
    OpenStruct.new @payload.fetch('source', {})
  end

  def version
    OpenStruct.new @payload.fetch('version', {})
  end

  def params
    OpenStruct.new @payload.fetch('params', {})
  end
end
