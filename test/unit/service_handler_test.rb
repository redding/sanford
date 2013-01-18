require 'assert'

require 'sanford/test_helpers'

module Sanford::ServiceHandler

  class BaseTest < Assert::Context
    include Sanford::TestHelpers

    desc "Sanford::ServiceHandler"
    setup do
      @handler = init_handler(TestServiceHandler)
    end
    subject{ @handler }

    should have_instance_methods :init, :init!, :run, :run!

    should "raise a NotImplementedError if run! is not overwritten" do
      assert_raises(NotImplementedError){ subject.run! }
    end

  end

  class WithMethodFlagsTest < BaseTest
    setup do
      @handler = init_handler(FlagServiceHandler)
    end

    should "have called `init!`" do
      assert_equal true, subject.init_bang_called
    end

    should "not have called `run!` or it's callbacks when initialized" do
      assert_nil subject.before_run_called
      assert_nil subject.run_bang_called
      assert_nil subject.after_run_called
    end

    should "call `run!` and it's callbacks when it's `run`" do
      subject.run

      assert_equal true, subject.before_run_called
      assert_equal true, subject.run_bang_called
      assert_equal true, subject.after_run_called
    end

  end

  class HaltTest < BaseTest
    desc "halt"

    should "return a response with the status code and the passed data" do
      response = run_handler(HaltServiceHandler, {
        'code'    => 648,
        'data'    => true
      })

      assert_equal 648,   response.status.code
      assert_equal true,  response.data
      assert_nil response.status.message
    end

    should "return a response with the status code for the named status and the passed message" do
      response = run_handler(HaltServiceHandler, {
        'code'    => 'ok',
        'message' => 'test message'
      })

      assert_equal 200,             response.status.code
      assert_equal 'test message',  response.status.message
      assert_nil response.data
    end

  end

  class HaltingTest < BaseTest
    desc "halting at different points"

    should "not call `run!` or it's callbacks when `init!` halts" do
      response = run_handler(HaltingBehaviorServiceHandler, {
        'when' => 'init!'
      })

      assert_equal 'init! halting', response.status.message
    end

    should "not call `run!` but should call `before_run` and `after_run` when `before_run` halts" do
      handler, response = run_and_return_handler(HaltingBehaviorServiceHandler, {
        'when' => 'before_run'
      })

      assert_equal true,  handler.init_bang_called
      assert_equal true,  handler.before_run_called
      assert_equal nil,   handler.run_bang_called
      assert_equal nil,   handler.after_run_called

      assert_equal 'before_run halting', response.status.message
    end

    should "call `before_run` and `run!` when `run!` halts" do
      handler, response = run_and_return_handler(HaltingBehaviorServiceHandler, {
        'when' => 'run!'
      })

      assert_equal true,  handler.init_bang_called
      assert_equal true,  handler.before_run_called
      assert_equal true,  handler.run_bang_called
      assert_equal nil,   handler.after_run_called

      assert_equal 'run! halting', response.status.message
    end

    should "call `before_run`, `run!` and `after_run` when `after_run` halts" do
      handler, response = run_and_return_handler(HaltingBehaviorServiceHandler, {
        'when' => 'after_run'
      })

      assert_equal true,  handler.init_bang_called
      assert_equal true,  handler.before_run_called
      assert_equal true,  handler.run_bang_called
      assert_equal true,  handler.after_run_called

      assert_equal 'after_run halting', response.status.message
    end

  end

end
