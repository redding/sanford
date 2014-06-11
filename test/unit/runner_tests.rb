require 'assert'
require 'sanford/runner'

require 'test/support/service_handlers'

module Sanford::Runner

  class UnitTests < Assert::Context
    desc "Sanford::Runner"
    setup do
      request = Sanford::Protocol::Request.new('test', {})
      @runner_class = Class.new do
        include Sanford::Runner
      end
      @runner = @runner_class.new(BasicServiceHandler, request)
    end
    subject{ @runner }

    should have_cmeths :run
    should have_readers :handler_class, :request, :logger, :handler
    should have_imeths :init, :init!, :run, :run!
    should have_imeths :halt, :catch_halt

    should "not implement the run behavior" do
      assert_raises NotImplementedError do
        subject.run
      end
    end

  end

  # runner behavior tests are handled via system tests

end
