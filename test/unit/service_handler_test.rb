require 'assert'

module Sanford::ServiceHandler

  class BaseTest < Assert::Context
    desc "Sanford::ServiceHandler"
    setup do
      @handler = StaticServiceHandler.new
    end
    subject{ @handler }

    should have_instance_methods :logger, :request, :init, :init!, :run, :run!, :halt, :params

    should "raise a NotImplementedError if run! is not overwritten" do
      assert_raises(NotImplementedError){ subject.run! }
    end
    should "return the request's params with #params" do
      assert_equal subject.request.params, subject.params
    end
  end

  class WithMethodFlagsTest < BaseTest
    setup do
      @handler = FlaggedServiceHandler.new
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

  class ManualWithThrowTest < BaseTest
    desc "run that manuallly throws `:halt`"
    setup do
      handler = ManualThrowServiceHandler.new
      @returned = handler.run
    end

    should "catch `:halt` and return what was thrown" do
      assert_equal 'halted!', @returned
    end
  end

  class HaltWithAStatusNameAndMessageTest < BaseTest
    desc "halt with a status name and a message"
    setup do
      @halt_with = { :code => :success, :message => "Just a test" }
      handler = HaltWithServiceHandler.new(@halt_with)
      @response_status, @result = handler.run
    end

    should "return a response with the status passed to halt and a nil result" do
      assert_equal @halt_with[:code],     @response_status.first
      assert_equal @halt_with[:message],  @response_status.last
      assert_equal @halt_with[:result],   @result
    end
  end

  class HaltWithAStatusCodeAndResultTest < BaseTest
    desc "halt with a status code and result"
    setup do
      @halt_with = { :code => 648, :result => true }
      handler = HaltWithServiceHandler.new(@halt_with)
      @response_status, @result = handler.run
    end

    should "return a response status and result when passed a number and a result option" do
      assert_equal @halt_with[:code],     @response_status.first
      assert_equal @halt_with[:message],  @response_status.last
      assert_equal @halt_with[:result],   @result
    end
  end

  class BeforeRunHaltsTest < BaseTest
    desc "if 'before_run' halts"
    setup do
      @handler = ConfigurableServiceHandler.new({
        :before_run => proc{ halt 601, :message => "before_run halted" }
      })
      @response_status, @result = @handler.run
    end

    should "only call 'before_run' and 'after_run'" do
      assert_equal true,  subject.before_run_called
      assert_equal false, subject.init_called
      assert_equal false, subject.init_bang_called
      assert_equal false, subject.run_bang_called
      assert_equal true,  subject.after_run_called
    end

    should "return the 'before_run' response" do
      assert_equal 601,                 @response_status.first
      assert_equal "before_run halted", @response_status.last
      assert_equal nil,                 @result
    end
  end

  class AfterRunHaltsTest < BaseTest
    desc "if 'after_run' halts"
    setup do
      @after_run = proc{ halt 801, :message => "after_run halted" }
    end

  end

  class AndBeforeRunHaltsTest < AfterRunHaltsTest
      desc "and 'before_run' halts"
      setup do
        @handler = ConfigurableServiceHandler.new({
          :before_run => proc{ halt 601, :message => "before_run halted" },
          :after_run  => @after_run
        })
        @response_status, @result = @handler.run
      end

      should "only call 'before_run' and 'after_run'" do
        assert_equal true,  subject.before_run_called
        assert_equal false, subject.init_called
        assert_equal false, subject.init_bang_called
        assert_equal false, subject.run_bang_called
        assert_equal true,  subject.after_run_called
      end

      should "return the 'after_run' response" do
        assert_equal 801,                 @response_status.first
        assert_equal "after_run halted",  @response_status.last
        assert_equal nil,                 @result
      end
    end

    class AndRunBangHaltsTest < AfterRunHaltsTest
      desc "and 'run!' halts"
      setup do
        @handler = ConfigurableServiceHandler.new({
          :run!       => proc{ halt 601, :message => "run! halted" },
          :after_run  => @after_run
        })
        @response_status, @result = @handler.run
      end

      should "call 'init!', 'run!' and the callbacks" do
        assert_equal true,  subject.before_run_called
        assert_equal true,  subject.init_called
        assert_equal true,  subject.init_bang_called
        assert_equal true,  subject.run_bang_called
        assert_equal true,  subject.after_run_called
      end

      should "return the 'after_run' response" do
        assert_equal 801,                 @response_status.first
        assert_equal "after_run halted",  @response_status.last
        assert_equal nil,                 @result
      end
    end

end
