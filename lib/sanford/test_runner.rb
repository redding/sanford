require 'sanford-protocol'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(RuntimeError)

  class TestRunner
    include Sanford::Runner

    attr_reader :response

    def initialize(handler_class, request_or_params, *args)
      if !handler_class.include?(Sanford::ServiceHandler)
        raise InvalidServiceHandlerError, "#{handler_class.inspect} is not a"\
                                          " Sanford::ServiceHandler"
      end

      super handler_class, build_request(request_or_params), *args
    end

    def init!
      @response = build_response catch(:halt){ @handler.init; nil }
    end

    # we override the `run` method because the TestRunner wants to control
    # storing any generated response. If `init` generated a response, we don't
    # want to `run` at all.

    def run
      @response ||= super.tap do |response|
        # attempt to serialize (and then throw away) the response data
        # this will error on the developer if BSON can't serialize their response
        Sanford::Protocol::BsonBody.new.encode(response.to_hash)
      end
    end

    def run!
      self.handler.run
    end

    private

    def build_request(req)
      !req.kind_of?(Sanford::Protocol::Request) ? test_request(req) : req
    end

    def test_request(params)
      Sanford::Protocol::Request.new('name', params || {})
    end

  end

end
