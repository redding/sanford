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

    should have_imeths :halted?, :run

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

    should "complain if the params can't be serialized" do
      params = { Factory.string => Class.new }
      assert_raises(BSON::InvalidDocument) do
        @runner_class.new(@handler_class, :params => params)
      end
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

    should "not be halted by default" do
      assert_false subject.halted?
    end

    should "not call `run` on its handler if halted when run" do
      catch(:halt){ subject.halt }
      assert_true subject.halted?
      subject.run
      assert_nil @handler.run_called
    end

    should "return its `to_response` value on run" do
      assert_equal subject.to_response, subject.run
    end

    should "complain if the respose value can't be encoded" do
      subject.data(Class.new)
      assert_raises(BSON::InvalidDocument){ subject.run }
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
