require 'ostruct'
require 'sanford-protocol'

require 'sanford/logger'

module Sanford

  class Runner

    ResponseArgs = Struct.new(:status, :data)

    attr_reader :handler_class, :request, :logger

    def initialize(handler_class, request, logger = nil)
      @handler_class, @request = handler_class, request
      @logger = logger || Sanford::NullLogger.new
      @handler = @handler_class.new(self)
    end

    def run
      response_args = catch_halt do
        @handler.init
        @handler.run
      end
      Sanford::Protocol::Response.new(response_args.status, response_args.data)
    end

    module HaltMethods

      # It's best to keep what `halt` and `catch_halt` return in the same format.
      # Currently this is a `ResponseArgs` object. This is so no matter how the
      # block returns (either by throwing or running normally), you get the same
      # thing kind of object.

      def halt(status, options = nil)
        options = OpenStruct.new(options || {})
        response_status = [ status, options.message ]
        throw :halt, ResponseArgs.new(response_status, options.data)
      end

      def catch_halt(&block)
        catch(:halt){ ResponseArgs.new(*block.call) }
      end

    end
    include HaltMethods

  end

end
