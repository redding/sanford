require 'ostruct'
require 'sanford-protocol'
require 'sanford/logger'
require 'sanford/template_source'

module Sanford

  module Runner

    ResponseArgs = Struct.new(:status, :data)

    def self.included(klass)
      klass.class_eval do
        include InstanceMethods
      end
    end

    module InstanceMethods

      attr_reader :handler_class, :request
      attr_reader :logger, :template_source
      attr_reader :handler

      def initialize(handler_class, request, server_data)
        @handler_class = handler_class
        @request = request
        @logger = server_data.logger || Sanford::NullLogger.new
        @template_source = server_data.template_source || Sanford::NullTemplateSource.new
        @handler = @handler_class.new(self)
      end

      def params
        @request.params
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

      private

      def catch_halt(&block)
        catch(:halt){ ResponseArgs.new(*block.call) }
      end

      def build_response(args)
        Sanford::Protocol::Response.new(args.status, args.data) if args
      end

    end

  end

end
