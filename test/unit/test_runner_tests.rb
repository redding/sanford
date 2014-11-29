require 'assert'
require 'sanford/test_runner'

class Sanford::TestRunner

  class UnitTests < Assert::Context
    desc "Sanford::TestRunner"
    setup do
      @handler_class = TestServiceHandler
      @runner_class = Sanford::TestRunner
    end
    subject{ @runner_class }

    should "be a runner" do
      assert_true subject < Sanford::Runner
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @params = { Factory.string => Factory.integer }
      @args = {
        :request => 'a-request',
        :params  => @params,
        :logger  => 'a-logger',
        :router  => 'a-router',
        :template_source => 'a-source'
      }
      @runner = @runner_class.new(@handler_class, @args)
    end
    subject{ @runner }

    should have_readers :response
    should have_imeths :run

    should "raise an invalid error when not passed a service handler" do
      assert_raises(Sanford::InvalidServiceHandlerError) do
        @runner_class.new(Class.new)
      end
    end

    should "super its standard attributes" do
      assert_equal 'a-request',  subject.request
      assert_equal @params,      subject.params
      assert_equal 'a-logger',   subject.logger
      assert_equal 'a-router',   subject.router
      assert_equal 'a-source',   subject.template_source
    end

    should "write any non-standard args on the handler" do
      runner = @runner_class.new(@handler_class, :custom_value => 42)
      assert_equal 42, runner.handler.custom_value
    end

    should "not have called its service handlers before callbacks" do
      assert_nil subject.handler.before_called
    end

    should "have called init on its service handler" do
      assert_true subject.handler.init_called
    end

    should "not have a response by default" do
      assert_nil subject.response
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

    should "not have called its service handlers after callbacks" do
      assert_nil @runner.handler.after_called
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

    attr_reader :before_called, :after_called
    attr_reader :init_called, :run_called
    attr_accessor :custom_value, :response

    before{ @before_called = true }
    after{ @after_called = true }

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
