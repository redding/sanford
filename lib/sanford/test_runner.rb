require 'sanford-protocol'
require 'sanford/logger'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(RuntimeError)

  class TestRunner
    include Sanford::Runner

    attr_reader :response

    def initialize(handler_class, args = nil)
      if !handler_class.include?(Sanford::ServiceHandler)
        raise InvalidServiceHandlerError, "#{handler_class.inspect} is not a"\
                                          " Sanford::ServiceHandler"
      end
      args = (args || {}).dup
      params  = args.delete(:params)  || {}
      request = args.delete(:request) || build_request(params)
      logger  = args.delete(:logger)  || Sanford::NullLogger.new

      super(handler_class, request, logger)
      args.each{ |key, value| @handler.send("#{key}=", value) }

      @response = build_response(catch(:halt){ @handler.init; nil })
    end

    # we override the `run` method because the TestRunner wants to control
    # storing any generated response. If `init` generated a response, we don't
    # want to `run` at all.

    def run
      @response ||= super
    end

    def run!
      self.handler.run
    end

    private

    def build_request(params)
      Sanford::Protocol::Request.new('name', params)
    end

    def build_response(args)
      response = super
      return if !response
      response.tap do |response|
        # attempt to serialize (and then throw away) the response data
        # this will error on the developer if BSON can't serialize their response
        Sanford::Protocol::BsonBody.new.encode(response.to_hash)
      end
    end

  end

end
