require 'assert'
require 'sanford/service_handler'

require 'bson'
require 'sanford/test_helpers'
require 'test/support/service_handlers'

module Sanford::ServiceHandler

  class UnitTests < Assert::Context
    include Sanford::TestHelpers

    desc "Sanford::ServiceHandler"
    setup do
      @handler_class = Class.new{ include Sanford::ServiceHandler }
    end
    subject{ @handler_class }

    should have_imeths :run
    should have_imeths :before_init_callbacks, :after_init_callbacks
    should have_imeths :before_run_callbacks,  :after_run_callbacks
    should have_imeths :before_init, :after_init
    should have_imeths :before_run,  :after_run
    should have_imeths :prepend_before_init, :prepend_after_init
    should have_imeths :prepend_before_run,  :prepend_after_run

    should "allow running a handler class with the class method #run" do
      response = HaltServiceHandler.run({
        'code'    => 648,
        'data'    => true
      })
      assert_equal 648,   response.code
      assert_equal true,  response.data
    end

    should "return an empty array by default using `before_init_callbacks`" do
      assert_equal [], subject.before_init_callbacks
    end

    should "return an empty array by default using `after_init_callbacks`" do
      assert_equal [], subject.after_init_callbacks
    end

    should "return an empty array by default using `before_run_callbacks`" do
      assert_equal [], subject.before_run_callbacks
    end

    should "return an empty array by default using `after_run_callbacks`" do
      assert_equal [], subject.after_run_callbacks
    end

    should "append a block to the before init callbacks using `before_init`" do
      subject.before_init_callbacks << proc{ }
      block = Proc.new{}
      subject.before_init(&block)
      assert_equal block, subject.before_init_callbacks.last
    end

    should "append a block to the after init callbacks using `after_init`" do
      subject.after_init_callbacks << proc{ }
      block = Proc.new{}
      subject.after_init(&block)
      assert_equal block, subject.after_init_callbacks.last
    end

    should "append a block to the before run callbacks using `before_run`" do
      subject.before_run_callbacks << proc{ }
      block = Proc.new{}
      subject.before_run(&block)
      assert_equal block, subject.before_run_callbacks.last
    end

    should "append a block to the after run callbacks using `after_run`" do
      subject.after_run_callbacks << proc{ }
      block = Proc.new{}
      subject.after_run(&block)
      assert_equal block, subject.after_run_callbacks.last
    end

    should "prepend a block to the before init callbacks using `prepend_before_init`" do
      subject.before_init_callbacks << proc{ }
      block = Proc.new{}
      subject.prepend_before_init(&block)
      assert_equal block, subject.before_init_callbacks.first
    end

    should "prepend a block to the after init callbacks using `prepend_after_init`" do
      subject.after_init_callbacks << proc{ }
      block = Proc.new{}
      subject.prepend_after_init(&block)
      assert_equal block, subject.after_init_callbacks.first
    end

    should "prepend a block to the before run callbacks using `prepend_before_run`" do
      subject.before_run_callbacks << proc{ }
      block = Proc.new{}
      subject.prepend_before_run(&block)
      assert_equal block, subject.before_run_callbacks.first
    end

    should "prepend a block to the after run callbacks using `prepend_after_run`" do
      subject.after_run_callbacks << proc{ }
      block = Proc.new{}
      subject.prepend_after_run(&block)
      assert_equal block, subject.after_run_callbacks.first
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @handler = test_runner(FlagServiceHandler).handler
    end
    subject{ @handler }

    should have_imeths :init, :init!, :run, :run!

    should "raise a NotImplementedError if run! is not overwritten" do
      handler = test_handler(@handler_class)
      assert_raises(NotImplementedError){ handler.run! }
    end

    should "have called `init!` and it's callbacks" do
      assert_true subject.before_init_called
      assert_true subject.second_before_init_called
      assert_true subject.init_bang_called
      assert_true subject.after_init_called
    end

    should "not have called `run!` or it's callbacks when initialized" do
      assert_nil subject.before_run_called
      assert_nil subject.run_bang_called
      assert_nil subject.after_run_called
      assert_nil subject.second_after_run_called
    end

    should "call `run!` and it's callbacks when it's `run`" do
      subject.run

      assert_true subject.before_run_called
      assert_true subject.run_bang_called
      assert_true subject.after_run_called
      assert_true subject.second_after_run_called
    end

  end

  class HaltTests < UnitTests
    desc "when halted"

    should "return a response with the status code and the passed data" do
      runner = test_runner(HaltServiceHandler, {
        'code'    => 648,
        'data'    => true
      })
      runner.run

      assert_equal 648, runner.response.code
      assert_true runner.response.data
      assert_nil runner.response.status.message
    end

    should "return a response with the status code for the named status and the passed message" do
      runner = test_runner(HaltServiceHandler, {
        'code'    => 'ok',
        'message' => 'test message'
      })
      runner.run

      assert_equal 200, runner.response.code
      assert_equal 'test message', runner.response.status.message
      assert_nil runner.response.data
    end

  end

  class HaltingTests < UnitTests
    desc "when halted at different points"

    should "not call `init!, `after_init`, `run!` or run's callbacks when `before_init` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'before_init'
      })
      response = runner.response

      assert_equal true, response.data[:before_init_called]
      assert_equal nil,  response.data[:init_bang_called]
      assert_equal nil,  response.data[:after_init_called]
      assert_equal nil,  response.data[:before_run_called]
      assert_equal nil,  response.data[:run_bang_called]
      assert_equal nil,  response.data[:after_run_called]

      assert_equal 'before_init halting', response.status.message
    end

    should "not call `after_init`, `run!` or it's callbacks when `init!` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'init!'
      })
      response = runner.response

      assert_equal true, response.data[:before_init_called]
      assert_equal true, response.data[:init_bang_called]
      assert_equal nil,  response.data[:after_init_called]
      assert_equal nil,  response.data[:before_run_called]
      assert_equal nil,  response.data[:run_bang_called]
      assert_equal nil,  response.data[:after_run_called]

      assert_equal 'init! halting', response.status.message
    end

    should "not call `run!` or it's callbacks when `after_init` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'after_init'
      })
      response = runner.response

      assert_equal true, response.data[:before_init_called]
      assert_equal true, response.data[:init_bang_called]
      assert_equal true, response.data[:after_init_called]
      assert_equal nil,  response.data[:before_run_called]
      assert_equal nil,  response.data[:run_bang_called]
      assert_equal nil,  response.data[:after_run_called]

      assert_equal 'after_init halting', response.status.message
    end

    should "not call `run!` or `after_run` when `before_run` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'before_run'
      })
      response = runner.run

      assert_equal true, response.data[:before_init_called]
      assert_equal true, response.data[:init_bang_called]
      assert_equal true, response.data[:after_init_called]
      assert_equal true, response.data[:before_run_called]
      assert_equal nil,  response.data[:run_bang_called]
      assert_equal nil,  response.data[:after_run_called]

      assert_equal 'before_run halting', runner.response.status.message
    end

    should "not call `after_run` when `run!` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'run!'
      })
      response = runner.run

      assert_equal true, response.data[:before_init_called]
      assert_equal true, response.data[:init_bang_called]
      assert_equal true, response.data[:after_init_called]
      assert_equal true, response.data[:before_run_called]
      assert_equal true, response.data[:run_bang_called]
      assert_equal nil,  response.data[:after_run_called]

      assert_equal 'run! halting', runner.response.status.message
    end

    should "call `init`, `run` and their callbacks when `after_run` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'after_run'
      })
      response = runner.run

      assert_equal true, response.data[:before_init_called]
      assert_equal true, response.data[:init_bang_called]
      assert_equal true, response.data[:after_init_called]
      assert_equal true, response.data[:before_run_called]
      assert_equal true, response.data[:run_bang_called]
      assert_equal true, response.data[:after_run_called]

      assert_equal 'after_run halting', runner.response.status.message
    end

  end

  class RenderHandlerTests < UnitTests
    desc "render helper method"

    should "render template files" do
      response = test_runner(RenderHandler).run
      assert_equal ['test_template', 'RenderHandler', {}], response.data
    end

  end

  class RunHandlerTests < UnitTests
    desc "run_handler helper"

    should "allow easily running another handler" do
      response = test_runner(RunOtherHandler).run
      assert_equal 'RunOtherHandler', response.data
    end

  end

  class InvalidHandlerTests < UnitTests
    desc "that is invalid"

    should "raise a custom error when initialized in a test" do
      assert_raises Sanford::InvalidServiceHandlerError do
        test_handler(InvalidServiceHandler)
      end
    end

  end

  class SerializeErrorTests < UnitTests
    desc "that failse to serialize to BSON"

    should "raise a BSON error when run in a test" do
      assert_raises BSON::InvalidDocument do
        test_runner(SerializeErrorServiceHandler).run
      end
    end

  end

end
