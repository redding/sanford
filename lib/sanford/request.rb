# A Sanford request is a specific type of Sanford message. It defines the
# structure of a request: service name, version and params. Furthermore, it
# defines how to take a serialized request string and build a Sanford request
# object from it with it's parse method.
#
require 'sanford/message'

module Sanford

  class Request < Sanford::Message

    def self.parse(serialized_body)
      body = super(serialized_body)
      self.new(body['name'], body['version'], body['params'])
    end

    attr_reader :service_name, :service_version, :params

    def initialize(service_name, service_version, params)
      @service_name, @service_version, @params = [ service_name, service_version, params ]
      super({
        'name'    => self.service_name,
        'version' => self.service_version,
        'params'  => self.params
      })
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @service_name=#{self.service_name.inspect} " \
      "@service_version=#{self.service_version.inspect} @params=#{self.params.inspect}>"
    end

  end

end
