require 'ostruct'
require 'sanford-protocol'

module Sanford

  module Runner

    ResponseArgs = Struct.new(:status, :data)

    def self.included(klass)
      klass.class_eval do
        include InstanceMethods
      end
    end

    module InstanceMethods

      attr_reader :handler_class, :request, :logger, :handler

      def initialize(handler_class, request, logger = nil)
        @handler_class, @request = handler_class, request
        @logger = logger || Sanford.config.logger
        @handler = @handler_class.new(self)
        self.init
      end

      def init
        self.init!
      end

      def init!
      end

      def run
        build_response catch_halt{ self.run! }
      end

      def run!
        raise NotImplementedError
      end

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

      protected

      def build_response(args)
        Sanford::Protocol::Response.new(args.status, args.data) if args
      end

    end

  end

end
