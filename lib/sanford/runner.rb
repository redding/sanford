require 'ostruct'
require 'sanford-protocol'

module Sanford

  module Runner

    ResponseArgs = Struct.new(:status, :data)

    attr_reader :handler_class, :request, :logger

    def self.included(klass)
      klass.class_eval{ extend ClassMethods }
    end

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
      response_args = catch_halt{ self.run!(@handler) }
      Sanford::Protocol::Response.new(response_args.status, response_args.data)
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

    module ClassMethods

      def run(handler_class, params = nil, logger = nil)
        request = Sanford::Protocol::Request.new('version', 'name', params || {})
        self.new(handler_class, request, logger).run
      end

    end

  end

  class DefaultRunner
    include Sanford::Runner

    def run!(handler)
      handler.init
      handler.run
    end

  end

end
