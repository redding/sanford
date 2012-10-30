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

  end

end
