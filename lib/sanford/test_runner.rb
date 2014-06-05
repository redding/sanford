require 'sanford-protocol'
require 'sanford/runner'

module Sanford

  class TestRunner
    include Sanford::Runner

    attr_reader :handler, :response

    def init!
      if !@request.kind_of?(Sanford::Protocol::Request)
        @request = test_request(@request)
      end
      @response = build_response catch(:halt){ @handler.init; nil }
    end

    # we override the `run` method because the TestRunner wants to control
    # storing any generated response. If `init` generated a response, we don't
    # want to `run` at all.

    def run
      @response ||= build_response catch_halt{ @handler.run }
    end

    protected

    def test_request(params)
      Sanford::Protocol::Request.new('name', params || {})
    end

    def build_response(response_args)
      Sanford::Protocol::Response.new(response_args.status, response_args.data) if response_args
    end

  end

end
