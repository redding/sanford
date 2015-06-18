require 'assert'
require 'sanford/route'

require 'sanford/server_data'
require 'sanford/service_handler'

class Sanford::Route

  class UnitTests < Assert::Context
    desc "Sanford::Route"
    setup do
      @name = Factory.string
      @handler_class_name = TestHandler.to_s
      @route = Sanford::Route.new(@name, @handler_class_name)
    end
    subject{ @route }

    should have_readers :name, :handler_class_name, :handler_class
    should have_imeths :validate!, :run

    should "know its name and handler class name" do
      assert_equal @name, subject.name
      assert_equal @handler_class_name, subject.handler_class_name
    end

    should "not know its handler class by default" do
      assert_nil subject.handler_class
    end

    should "constantize its handler class after being validated" do
      subject.validate!
      assert_equal TestHandler, subject.handler_class
    end

  end

  class RunTests < UnitTests
    desc "when run"
    setup do
      @runner_spy = SanfordRunnerSpy.new
      Assert.stub(Sanford::SanfordRunner, :new) do |*args|
        @runner_spy.build(*args)
        @runner_spy
      end

      @request = OpenStruct.new('params' => 'some-params')
      @server_data = Sanford::ServerData.new

      @route.validate!
      @response = @route.run(@request, @server_data)
    end
    subject{ @response }

    should "build and run a sanford runner" do
      assert_equal @route.handler_class, @runner_spy.handler_class

      exp_args = {
        :request => @request,
        :params  => @request.params,
        :logger  => @server_data.logger,
        :router  => @server_data.router,
        :template_source => @server_data.template_source
      }
      assert_equal exp_args, @runner_spy.args

      assert_true @runner_spy.run_called
    end

    should "return the response from the running the runner" do
      assert_equal @runner_spy.response, subject
    end

  end

  class InvalidHandlerClassNameTests < UnitTests
    desc "with an invalid handler class name"
    setup do
      @route = Sanford::Route.new(@name, Factory.string)
    end

    should "raise a no handler class error when validated" do
      assert_raises(Sanford::NoHandlerClassError){ subject.validate! }
    end

  end

  TestHandler = Class.new

  class SanfordRunnerSpy

    attr_reader :run_called
    attr_reader :handler_class, :args
    attr_reader :request, :params, :logger, :router, :template_source
    attr_reader :response

    def initialize
      @run_called = false
    end

    def build(handler_class, args)
      @handler_class, @args = handler_class, args

      @request = args[:request]
      @params  = args[:params]
      @logger  = args[:logger]
      @router  = args[:router]
      @template_source = args[:template_source]

      @response = Factory.string
    end

    def run
      @run_called = true
      @response
    end

  end

end
