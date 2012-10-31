require 'assert'

module Sanford::ServiceHandler

  class BaseTest < Assert::Context
    desc "Sanford::ServiceHandler"
    setup do
      @logger = Sanford::NullLogger.new
      @request = Sanford::Request.new('something', 'v1', {})
      @handler_class = Class.new do
        include Sanford::ServiceHandler
      end
      @handler = @handler_class.new(@logger, @request)
    end
    subject{ @handler }

    should have_instance_methods :logger, :request, :init, :init!, :run, :run!, :halt
  end

  class InitTest < BaseTest
    desc "init method"
    setup do
      @handler_class.class_eval do
        attr_reader :init_bang_been_called
        def initialize(*passed)
          super
          @init_bang_been_called = false
        end
        def init!
          @init_bang_been_called = true
        end
      end
      @handler = @handler_class.new(@logger, @request)
      @handler.init
    end

    should "should call the `init!` method" do
      assert_equal true, subject.init_bang_been_called
    end
  end

  class RunTest < BaseTest
    desc "run method"
    setup do
      @handler_class.class_eval do
        attr_reader :init_been_called, :run_bang_been_called
        def initialize(*passed)
          super
          @init_been_called = false
          @run_bang_been_called = false
        end
        def init
          @init_been_called = true
        end
        def run!
          @run_bang_been_called = true
        end
      end
      @handler = @handler_class.new(@logger, @request)
    end

    should "run the `init` and `run!` method" do
      subject.run

      assert_equal true, subject.init_been_called
      assert_equal true, subject.run_bang_been_called
    end
  end

  class RunWithThrowTest < BaseTest
    desc "run method"
    setup do
      @handler_class.class_eval do
        attr_reader :run_bang_been_called
        def initialize(*passed)
          super
          @run_bang_been_called = false
        end
        def init
          throw(:halt, 'halted!')
        end
        def run!
          @run_bang_been_called = true
        end
      end
      @handler = @handler_class.new(@logger, @request)
    end

    should "catch `:halt` if it is thrown" do
      result = subject.run

      assert_equal 'halted!', result
      assert_equal false, subject.run_bang_been_called
    end
  end

  class RunBangTest < BaseTest
    desc "run! method"

    should "raise a NotImplementedError if not overwritten" do
      assert_raises(NotImplementedError) do
        subject.run!
      end
    end
  end

  class HaltTest < BaseTest
    desc "halt method"
    setup do
      @handler_class.class_eval do
        def run!
          halt *self.request.params['halt_with']
        end
      end
    end

    should "make `run` return a response status and result based on what is passed" do
      halt_with = [ :success, { :message => "Just a test" } ]
      request = Sanford::Request.new('something', 'v1', { 'halt_with' => halt_with })
      handler = @handler_class.new(@logger, request)
      result = handler.run

      assert_instance_of Sanford::Response::Status, result.first
      assert_equal Sanford::Response::Status::CODES[halt_with.first], result.first.code
      assert_equal halt_with.last[:message], result.first.message
      assert_equal nil, result.last
    end
    should "return a response status and result when passed a number and a result option" do
      halt_with = [ 648, { :result => true } ]
      request = Sanford::Request.new('something', 'v1', { 'halt_with' => halt_with })
      handler = @handler_class.new(@logger, request)
      result = handler.run

      assert_equal halt_with.first, result.first.code
      assert_equal nil, result.first.message
      assert_equal halt_with.last[:result], result.last
    end
  end

end
