require 'sanford-protocol'
require 'sanford/logger'
require 'sanford/template_source'

module Sanford

  class Runner

    ResponseArgs = Struct.new(:status, :data)

    attr_reader :handler_class, :handler
    attr_reader :request, :params, :logger, :template_source

    def initialize(handler_class)
      @handler_class = handler_class
      @handler = @handler_class.new(self)
    end

    def run
      raise NotImplementedError
    end

    # It's best to keep what `halt` and `catch_halt` return in the same format.
    # Currently this is a `ResponseArgs` object. This is so no matter how the
    # block returns (either by throwing or running normally), you get the same
    # thing kind of object.

    def halt(status, options = nil)
      options ||= {}
      message = options[:message] || options['message']
      response_status = [ status, message ]
      response_data = options[:data] || options['data']
      throw :halt, ResponseArgs.new(response_status, response_data)
    end

    private

    def catch_halt(&block)
      catch(:halt){ ResponseArgs.new(*block.call) }
    end

    def build_response(&block)
      args = catch_halt(&block)
      Sanford::Protocol::Response.new(args.status, args.data)
    end

  end

end
