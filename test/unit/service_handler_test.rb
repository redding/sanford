require 'assert'

module Sanford::ServiceHandler

  class BaseTest < Assert::Context
    desc "Sanford::ServiceHandler"
    setup do
      @logger = Sanford::NullLogger.new
      @request = Sanford::Request.new('something', 'v1', {})
      @handler_class = Factory.service_handler(:with_flags => false)
      @handler = @handler_class.new(@logger, @request)
    end
    subject{ @handler }

    should have_instance_methods :logger, :request, :init, :init!, :run, :run!, :halt
  end

  class WithMethodFlagsTest < BaseTest
    setup do
      @handler_class = Factory.service_handler(:with_flags => true)
      @handler = @handler_class.new(@logger, @request)
    end

    should "should call the `init!` method when `init` is called" do
      subject.init

      assert_equal true, subject.init_bang_called
    end
    should "run the `init` and `run!` method when `run` is called" do
      subject.run

      assert_equal true, subject.init_called
      assert_equal true, subject.run_bang_called
    end
    should "run it's callbacks when `run` is called" do
      subject.run

      assert_equal true, subject.before_run_called
      assert_equal true, subject.after_run_called
    end
  end

  class RunWithThrowTest < BaseTest
    desc "run method that throws `:halt`"
    setup do
      handler_class = Factory.service_handler(:with_flags => true) do
        def init
          throw(:halt, 'halted!')
        end
      end
      @handler = handler_class.new(@logger, @request)
      @result = @handler.run
    end

    should "catch `:halt` and return what was thrown" do
      assert_equal 'halted!', @result
      assert_equal false, subject.run_bang_called
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
      @handler_class = Factory.service_handler(:with_flags => false) do
        def run!
          halt *self.request.params['halt_with']
        end
      end
    end

  end

  class WithAStatusNameAndMessageTest < HaltTest
    desc "with a status name and a message"
    setup do
      @halt_with = [ :success, { :message => "Just a test" } ]
      request = Sanford::Request.new('something', 'v1', { 'halt_with' => @halt_with })
      @handler = @handler_class.new(@logger, request)
      @result = @handler.run
    end

    should "return a response with the status passed to halt and a nil result" do
      assert_instance_of Sanford::Response::Status, @result.first
      assert_equal Sanford::Response::Status::CODES[@halt_with.first], @result.first.code
      assert_equal @halt_with.last[:message], @result.first.message
      assert_equal nil, @result.last
    end
  end

  class WithAStatusCodeAndResultTest < HaltTest
    desc "with a status code and result"
    setup do
      @halt_with = [ 648, { :result => true } ]
      request = Sanford::Request.new('something', 'v1', { 'halt_with' => @halt_with })
      handler = @handler_class.new(@logger, request)
      @result = handler.run
    end

    should "return a response status and result when passed a number and a result option" do
      assert_equal @halt_with.first, @result.first.code
      assert_equal nil, @result.first.message
      assert_equal @halt_with.last[:result], @result.last
    end
  end

  class BeforeRunHaltsTest < BaseTest
    desc "if 'before_run' halts"
    setup do
      handler_class = Factory.service_handler(:with_flags => true) do
        def before_run
          super
          halt 601, :message => "before_run halted"
        end
      end
      @handler = handler_class.new(@logger, @request)
      @result = @handler.run
    end

    should "only call 'before_run' and 'after_run'" do
      assert_equal true,  subject.before_run_called
      assert_equal false, subject.init_called
      assert_equal false, subject.init_bang_called
      assert_equal false, subject.run_bang_called
      assert_equal true,  subject.after_run_called
    end

    should "return the 'before_run' response" do
      assert_equal 601,                 @result.first.code
      assert_equal "before_run halted", @result.first.message
      assert_equal nil,                 @result.last
    end
  end

  class AfterRunHaltsTest < BaseTest
    desc "if 'after_run' halts"
    setup do
      @handler_class = Factory.service_handler(:with_flags => true) do
        def after_run
          super
          halt 801, :message => "after_run halted"
        end
      end
    end

  end

  class AndBeforeRunHaltsTest < AfterRunHaltsTest
      desc "and 'before_run' halts"
      setup do
        @handler_class.class_eval do
          def before_run
            super
            halt 601, :message => "before_run halted"
          end
        end
        @handler = @handler_class.new(@logger, @request)
        @result = @handler.run
      end

      should "only call 'before_run' and 'after_run'" do
        assert_equal true,  subject.before_run_called
        assert_equal false, subject.init_called
        assert_equal false, subject.init_bang_called
        assert_equal false, subject.run_bang_called
        assert_equal true,  subject.after_run_called
      end

      should "return the 'after_run' response" do
        assert_equal 801,                 @result.first.code
        assert_equal "after_run halted",  @result.first.message
        assert_equal nil,                 @result.last
      end
    end

    class AndRunBangHaltsTest < AfterRunHaltsTest
      desc "and 'before_run' halts"
      setup do
        @handler_class.class_eval do
          def run!
            super
            halt 601, :message => "run! halted"
          end
        end
        @handler = @handler_class.new(@logger, @request)
        @result = @handler.run
      end

      should "call 'init!', 'run!' and the callbacks" do
        assert_equal true,  subject.before_run_called
        assert_equal true,  subject.init_called
        assert_equal true,  subject.init_bang_called
        assert_equal true,  subject.run_bang_called
        assert_equal true,  subject.after_run_called
      end

      should "return the 'after_run' response" do
        assert_equal 801,                 @result.first.code
        assert_equal "after_run halted",  @result.first.message
        assert_equal nil,                 @result.last
      end
    end

end
