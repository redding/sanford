require 'sanford-protocol'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(RuntimeError)

  class TestRunner
    include Sanford::Runner

    attr_reader :handler, :response

    def initialize(handler_class, *args)
      if !handler_class.include?(Sanford::ServiceHandler)
        raise InvalidServiceHandlerError, "#{handler_class.inspect} is not a"\
                                          " Sanford::ServiceHandler"
      end
      super
    end

    def init!
      if !@request.kind_of?(Sanford::Protocol::Request)
        @request = test_request(@request)
      end
      @response = build_response catch(:halt){ @handler.init; nil }
    end

    # we override the `run` method because the TestRunner wants to control
    # storing any generated response. If `init` generated a response, we don't
    # want to `run` at all.

    def run
      @response ||= build_response(catch_halt{ @handler.run }).tap do |response|
        # attempt to serialize (and then throw away) the response data
        # this will error on the developer if BSON can't serialize their response
        Sanford::Protocol::BsonBody.new.encode(response.to_hash)
      end
    end

    protected

    def test_request(params)
      Sanford::Protocol::Request.new('name', params || {})
    end

    def build_response(response_args)
      Sanford::Protocol::Response.new(response_args.status, response_args.data) if response_args
    end

  end

end
