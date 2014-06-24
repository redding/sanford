require 'assert'
require 'sanford/test_runner'

class Sanford::TestRunner

  class UnitTests < Assert::Context
    desc "Sanford::TestRunner"
    setup do
      @handler_class = TestServiceHandler
      @logger = Factory.string
      @params = { :something => Factory.string }
      @request = Sanford::Protocol::Request.new(Factory.string, {
        :other => Factory.string
      })
      @handler_flag = Factory.boolean

      @runner_class = Sanford::TestRunner
    end
    subject{ @runner_class }

    should "be a runner" do
      assert_includes Sanford::Runner, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class, {
        :logger => @logger,
        :params => @params,
        :flag => @handler_flag
      })
    end
    subject{ @runner }

    should have_readers :response
    should have_imeths :run, :run!

    should "know its logger" do
      assert_equal @logger, subject.logger
    end

    should "build a request using the params" do
      assert_equal 'name', subject.request.name
      assert_equal @params, subject.request.params
    end

    should "write extra args to its service handler" do
      assert_equal @handler_flag, subject.handler.flag
    end

    should "take a request over params if provided" do
      test_runner = @runner_class.new(@handler_class, {
        :params => @params,
        :request => @request
      })
      assert_equal @request, test_runner.request
    end

    should "default its logger, params and request" do
      test_runner = @runner_class.new(@handler_class)
      assert_instance_of Sanford::NullLogger, test_runner.logger
      expected = Sanford::Protocol::Request.new('name', {})
      assert_equal expected, test_runner.request
    end

    should "have called init on its service handler" do
      assert_true subject.handler.init_called
    end

    should "not have a response by default" do
      assert_nil subject.response
    end

    should "raise an invalid error when not passed a service handler" do
      assert_raises(Sanford::InvalidServiceHandlerError) do
        @runner_class.new(Class.new)
      end
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @response = @runner.run
    end
    subject{ @response }

    should "know its response" do
      assert_equal subject, @runner.response
      assert_instance_of Sanford::Protocol::Response, subject
    end

    should "have called run on its service handler" do
      assert_true @runner.handler.run_called
    end

  end

  class RunWithInvalidResponseTests < InitTests
    desc "and run with an invalid response"
    setup do
      @runner.handler.response = Class.new
    end

    should "raise a serialization error" do
      assert_raises(BSON::InvalidDocument){ subject.run }
    end

  end

  class InitThatHaltsTests < UnitTests
    desc "when init with a handler that halts in its init"
    setup do
      @runner = @runner_class.new(HaltServiceHandler)
    end
    subject{ @runner }

    should "know the response from the init halting" do
      assert_instance_of Sanford::Protocol::Response, subject.response
      assert_equal subject.handler.response_code, subject.response.code
    end

  end

  class RunWithInitThatHaltsTests < InitThatHaltsTests
    desc "is run"
    setup do
      @response = @runner.run
    end
    subject{ @response }

    should "not call run on the service handler" do
      assert_false @runner.handler.run_called
    end

    should "return the response from the init halting" do
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @runner.handler.response_code, subject.code
    end

  end

  class RunWithInvalidResponseFromInitHaltTests < UnitTests
    desc "when init with a handler that halts in its init an invalid response"

    should "raise a serialization error" do
      assert_raises(BSON::InvalidDocument) do
        @runner_class.new(HaltServiceHandler, :response_data => Class.new)
      end
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

    attr_reader :init_called, :run_called
    attr_accessor :flag, :response

    def init!
      @init_called = true
      @run_called = false
    end

    def run!
      @run_called = true
      @response || Factory.boolean
    end
  end

  class HaltServiceHandler
    include Sanford::ServiceHandler

    attr_reader :run_called
    attr_accessor :response_code, :response_data

    def init!
      @run_called = false
      @response_code ||= Factory.integer
      @response_data ||= Factory.string
      halt(@response_code, :data => @response_data)
    end

    def run!
      @run_called = true
    end
  end

end
