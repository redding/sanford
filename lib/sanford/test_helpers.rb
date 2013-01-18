require 'sanford-protocol'

require 'sanford/runner'

module Sanford

  module TestHelpers
    module_function

    def init_handler(*args)
      runner = build_sanford_runner(*args)
      result = runner.init_handler
      raise HaltWhenInitError.new(runner, result) if result.kind_of?(Sanford::Runner::ResponseData)
      result
    end

    def run_handler(*args)
      handler, response = run_and_return_handler(*args)
      response
    end

    def run_and_return_handler(*args)
      runner = build_sanford_runner(*args)
      runner.response_and_handler
    end

    def build_sanford_runner(handler_class, params = {}, logger = nil)
      request = params.kind_of?(Sanford::Protocol::Request) ? params : test_request(params)
      Sanford::TestRunner.new(handler_class, request, logger)
    end

    def test_request(params)
      Sanford::Protocol::Request.new('test_version', 'test_service', params)
    end

  end

  class TestRunner < Sanford::Runner

    def build_handler
      @handler_class.new(self)
    end

    def init_handler
      catch(:halt){ self.build_handler }
    end

    def response_and_handler
      response_data = catch(:halt) do
        @handler = self.build_handler
        Sanford::Runner::ResponseData.new(*@handler.run)
      end
      response = Sanford::Protocol::Response.new(response_data.status, response_data.data)
      [ @handler, response ]
    end

  end

  class HaltWhenInitError < RuntimeError

    def initialize(runner, response_data)
      set_backtrace(response_data.backtrace) if response_data.backtrace
      super "The handler class #{runner.handler_class} couldn't be initialized because it halted."
    end

  end

end
