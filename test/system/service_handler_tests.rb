require 'assert'
require 'sanford/service_handler'

require 'test/support/app_server'

module Sanford::ServiceHandler

  class SystemTests < Assert::Context
    include Sanford::ServiceHandler::TestHelpers

    desc "Sanford::ServiceHandler"

  end

  class EchoHandlerTests < SystemTests
    desc "AppHandlers::Echo"
    setup do
      @params = { 'message' => Factory.text }
      @runner = test_runner(AppHandlers::Echo, :params => @params)
      @handler = @runner.handler
    end
    subject{ @handler }

    should "return a 200 response using the message param when run" do
      response = @runner.run
      assert_equal 200, response.code
      assert_equal @params['message'], response.data
    end

  end

  class RaiseHandlerTests < SystemTests
    desc "AppHandlers::Raise"
    setup do
      @runner = test_runner(AppHandlers::Raise)
      @handler = @runner.handler
    end
    subject{ @handler }

    should "raise a runtime error when run" do
      assert_raises(RuntimeError){ @runner.run }
    end

  end

  class BadResponseHandlerTests < SystemTests
    desc "AppHandlers::BadResponse"
    setup do
      @runner = test_runner(AppHandlers::BadResponse)
      @handler = @runner.handler
    end
    subject{ @handler }

    should "raise a invalid response error when run" do
      assert_raises(BSON::InvalidDocument){ @runner.run }
    end

  end

  class RenderTemplateHandlerTests < SystemTests
    desc "AppHandlers::RenderTemplate"
    setup do
      @params = { 'message' => Factory.text }
      @runner = test_runner(AppHandlers::RenderTemplate, {
        :params          => @params,
        :template_source => AppServer.config.template_source
      })
      @handler = @runner.handler
    end
    subject{ @handler }

    should have_readers :message

    should "know its message" do
      assert_equal @params['message'], subject.message
    end

    should "return a 200 response and render the template when run" do
      response = @runner.run
      assert_equal 200, response.code

      exp = "ERB Template Message: #{@params['message']}\n"
      assert_equal exp, response.data
    end

  end

  class PartialTemplateHandlerTests < SystemTests
    desc "AppHandlers::PartialTemplate"
    setup do
      @params = { 'message' => Factory.text }
      @runner = test_runner(AppHandlers::PartialTemplate, {
        :params          => @params,
        :template_source => AppServer.config.template_source
      })
      @handler = @runner.handler
    end
    subject{ @handler }

    should have_readers :message

    should "know its message" do
      assert_equal @params['message'], subject.message
    end

    should "return a 200 response and render the template when run" do
      response = @runner.run
      assert_equal 200, response.code

      exp = "ERB Template Message: \n"
      assert_equal exp, response.data
    end

  end

  class HaltHandlerTests < SystemTests
    desc "AppHandlers::Halt"
    setup do
      @handler_class = AppHandlers::Halt
    end

  end

  class RunHaltBeforeTests < HaltHandlerTests
    desc "run when halting in a before callback"
    setup do
      @params = { 'when' => 'before' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "not have halted because before callbacks aren't called" do
      assert_equal 200, subject.code
      assert_equal false, subject.data
    end

  end

  class RunHaltBeforeInitTests < HaltHandlerTests
    desc "run when halting in a before init callback"
    setup do
      @params = { 'when' => 'before_init' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in a before init callback" do
      assert_equal 200, subject.code
      assert_equal 'in before init', subject.status.message
    end

  end

  class RunHaltInitTests < HaltHandlerTests
    desc "run when halting in init"
    setup do
      @params = { 'when' => 'init' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in init" do
      assert_equal 200, subject.code
      assert_equal 'in init', subject.status.message
    end

  end

  class RunHaltAfterInitTests < HaltHandlerTests
    desc "run when halting in a after init callback"
    setup do
      @params = { 'when' => 'after_init' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in a after init callback" do
      assert_equal 200, subject.code
      assert_equal 'in after init', subject.status.message
    end

  end

  class RunHaltBeforeRunTests < HaltHandlerTests
    desc "run when halting in a before run callback"
    setup do
      @params = { 'when' => 'before_run' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in a before run callback" do
      assert_equal 200, subject.code
      assert_equal 'in before run', subject.status.message
    end

  end

  class RunHaltRunTests < HaltHandlerTests
    desc "run when halting in run"
    setup do
      @params = { 'when' => 'run' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in run" do
      assert_equal 200, subject.code
      assert_equal 'in run', subject.status.message
    end

  end

  class RunHaltAfterRunTests < HaltHandlerTests
    desc "run when halting in a after run callback"
    setup do
      @params = { 'when' => 'after_run' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "return the resposne from halting in a after run callback" do
      assert_equal 200, subject.code
      assert_equal 'in after run', subject.status.message
    end

  end

  class RunHaltAfterTests < HaltHandlerTests
    desc "run when halting in a after callback"
    setup do
      @params = { 'when' => 'after' }
      @runner = test_runner(@handler_class, :params => @params)
      @response = @runner.run
    end
    subject{ @response }

    should "not have halted because after callbacks aren't called" do
      assert_equal 200, subject.code
      assert_equal false, subject.data
    end

  end

end
