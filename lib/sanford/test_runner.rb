require 'sanford-protocol'
require 'sanford/runner'
require 'sanford/service_handler'

module Sanford

  InvalidServiceHandlerError = Class.new(StandardError)

  class TestRunner < Runner

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

      @halted = false
      catch(:halt){ self.handler.sanford_init }
    end

    def halted?; @halted; end

    def run
      catch(:halt){ self.handler.sanford_run } if !self.halted?
      self.to_response
    end

    # attempt to encode (and then throw away) the response
    # this will error on the developer if it can't encode their response
    def to_response
      super.tap do |response|
        Sanford::Protocol.msg_body.encode(response.to_hash) if response
      end
    end

    # helpers

    def halt(*args)
      @halted = true
      super
    end

    private

    # stringify and encode/decode to ensure params are valid and are
    # in the format they would normally be when a handler is built and run.
    def normalize_params(params)
      p = Sanford::Protocol::StringifyParams.new(params)
      Sanford::Protocol.msg_body.decode(Sanford::Protocol.msg_body.encode(p))
    end

  end

end
