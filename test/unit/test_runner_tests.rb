require 'assert'
require 'sanford/test_runner'

class Sanford::TestRunner

  class UnitTests < Assert::Context
    desc "Sanford::TestRunner"
    setup do
      @handler_class = TestServiceHandler
      @runner_class  = Sanford::TestRunner
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
        :logger          => Factory.string,
        :router          => Factory.string,
        :template_source => Factory.string,
        :request         => Factory.string,
        :params          => @params,
        :custom_value    => Factory.integer
      }
      @original_args = @args.dup
      @runner  = @runner_class.new(@handler_class, @args)
      @handler = @runner.handler
    end
    subject{ @runner }

    should have_readers :response
    should have_imeths :run

    should "raise an invalid error when passed a non service handler" do
      assert_raises(Sanford::InvalidServiceHandlerError) do
        @runner_class.new(Class.new)
      end
    end

    should "know its standard args" do
      assert_equal @args[:logger],          subject.logger
      assert_equal @args[:router],          subject.router
      assert_equal @args[:template_source], subject.template_source
      assert_equal @args[:request],         subject.request
      assert_equal @args[:params],          subject.params
    end

    should "write any non-standard args to its handler" do
      assert_equal @args[:custom_value], subject.handler.custom_value
    end

    should "not alter the args passed to it" do
      assert_equal @original_args, @args
    end

    should "not call its handler's before callbacks" do
      assert_nil @handler.before_called
    end

    should "call its handler's init" do
      assert_true @handler.init_called
    end

    should "not call its handler's run" do
      assert_nil @handler.run_called
    end

    should "not call its handler's after callbacks" do
      assert_nil @handler.after_called
    end

    should "not have a response by default" do
      assert_nil @handler.response
    end

    should "normalize the params passed to it" do
      params = {
        Factory.string        => Factory.string,
        Factory.string.to_sym => Factory.string.to_sym,
        Factory.integer       => Factory.integer
      }
      runner = @runner_class.new(@handler_class, :params => params)
      exp = Sanford::Protocol::StringifyParams.new(params)
      assert_equal exp, runner.params
    end

    should "raise a serialization error if the params can't be serialized" do
      params = { Factory.string => Class.new }
      assert_raises(BSON::InvalidDocument) do
        @runner_class.new(@handler_class, :params => params)
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

    should "run its service handler" do
      assert_true @runner.handler.run_called
    end

    should "not call its service handler's after callbacks" do
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
