require 'sanford-protocol'

require 'sanford/runner'

module Sanford

  class TestRunner
    include Sanford::Runner::HaltMethods

    attr_reader :handler, :response, :request, :logger

    def initialize(handler_class, params = {}, logger = nil)
      @handler_class = handler_class
      @request       = params.kind_of?(Sanford::Protocol::Request) ? params : test_request(params)
      @logger        = logger || Sanford.config.logger

      @handler  = @handler_class.new(self)
      @response = build_response catch(:halt){ @handler.init; nil }
    end

    def run
      @response ||= build_response catch_halt{ @handler.run }
    end

    protected

    def test_request(params)
      Sanford::Protocol::Request.new('test_version', 'test_service', params)
    end

    def build_response(response_args)
      Sanford::Protocol::Response.new(response_args.status, response_args.data) if response_args
    end

    module Helpers
      module_function

      def test_runner(*args)
        TestRunner.new(*args)
      end

    end

  end

end
