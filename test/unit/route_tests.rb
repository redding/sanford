require 'assert'
require 'sanford/route'

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
      @route.validate!
      @request = Factory.string
      @logger  = Factory.string

      @runner_spy = RunnerSpy.new(Factory.text)
      Sanford::SanfordRunner.stubs(:new).tap do |s|
        s.with(@route.handler_class, @request, @logger)
        s.returns(@runner_spy)
      end

      @response = @route.run(@request, @logger)
    end
    teardown do
      Sanford::SanfordRunner.unstub(:new)
    end
    subject{ @response }

    should "build and run a sanford runner" do
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

  class RunnerSpy
    attr_reader :response, :run_called

    def initialize(response)
      @response = response
      @run_called = false
    end

    def run
      @run_called = true
      @response
    end
  end

end
