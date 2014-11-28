require 'sanford-protocol'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(StandardError)

  class TestRunner < Runner

    attr_reader :response

    def initialize(handler_class, args = nil)
      if !handler_class.include?(Sanford::ServiceHandler)
        raise InvalidServiceHandlerError, "#{handler_class.inspect} is not a"\
                                          " Sanford::ServiceHandler"
      end

      args = (args || {}).dup
      super(handler_class, {
        :request => args.delete(:request),
        :params  => args.delete(:params),
        :logger  => args.delete(:logger),
        :router  => args.delete(:router),
        :template_source => args.delete(:template_source)
      })
      args.each{ |key, value| @handler.send("#{key}=", value) }

      return_value = catch(:halt){ @handler.init; nil }
      @response = build_and_serialize_response{ return_value } if return_value
    end

    # If `init` generated a response, we don't want to `run` at all. This makes
    # the `TestRunner` behave similar to the `SanfordRunner`, i.e. `halt` in
    # `init` stops processing where `halt` is called.

    def run
      @response ||= build_and_serialize_response{ self.handler.run }
    end

    private

    def build_and_serialize_response(&block)
      build_response(&block).tap do |response|
        # attempt to serialize (and then throw away) the response data
        # this will error on the developer if BSON can't serialize their response
        Sanford::Protocol::BsonBody.new.encode(response.to_hash) if response
      end
    end

  end

end
