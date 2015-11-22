require 'sanford-protocol'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(StandardError)

  class TestRunner < Runner

    attr_reader :response

    def initialize(handler_class, args = nil)
      if !handler_class.include?(Sanford::ServiceHandler)
        raise InvalidServiceHandlerError, "#{handler_class.inspect} is not a " \
                                          "Sanford::ServiceHandler"
      end

      a = (args || {}).dup
      super(handler_class, {
        :logger          => a.delete(:logger),
        :router          => a.delete(:router),
        :template_source => a.delete(:template_source),
        :request         => a.delete(:request),
        :params          => normalize_params(a.delete(:params) || {})
      })
      a.each{ |key, value| @handler.send("#{key}=", value) }

      return_value = catch(:halt){ @handler.sanford_init; nil }
      @response = build_and_serialize_response{ return_value } if return_value
    end

    # If `init` generated a response, we don't want to `run` at all. This makes
    # the `TestRunner` behave similar to the `SanfordRunner`, i.e. `halt` in
    # `init` stops processing where `halt` is called.

    def run
      @response ||= build_and_serialize_response{ self.handler.sanford_run }
    end

    private

    # Stringify and encode/decode to ensure params are valid and are
    # in the format they would normally be when a handler is built and run.
    def normalize_params(params)
      p = Sanford::Protocol::StringifyParams.new(params)
      Sanford::Protocol.msg_body.decode(Sanford::Protocol.msg_body.encode(p))
    end

    def build_and_serialize_response(&block)
      build_response(&block).tap do |response|
        # attempt to serialize (and then throw away) the response data
        # this will error on the developer if it can't serialize their response
        Sanford::Protocol.msg_body.encode(response.to_hash) if response
      end
    end

  end

end
