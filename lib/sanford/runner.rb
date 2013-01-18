require 'sanford-protocol'

require 'sanford/logger'

module Sanford

  class Runner

    ResponseData = Struct.new(:status, :data, :backtrace)

    attr_reader :handler_class, :request, :logger

    def initialize(handler_class, request, logger = nil)
      @handler_class, @request = handler_class, request
      @logger = logger || Sanford::NullLogger.new
    end

    def run
      response_data = catch_halt{ @handler_class.new(self).run }
      Sanford::Protocol::Response.new(response_data.status, response_data.data)
    end

    # It's best to keep what `halt` and `catch_halt` return in the same format.
    # Currently this is a `ResponseData` object. This is so no matter how the
    # block returns (either by throwing or running normally), you get the same
    # thing kind of object.

    def halt(status, options = nil, called_from = caller)
      options = OpenStruct.new(options || {})
      response_status = [ status, options.message ]
      throw :halt, ResponseData.new(response_status, options.data, called_from)
    end

    def catch_halt(&block)
      catch(:halt){ ResponseData.new(*block.call) }
    end

  end

end
