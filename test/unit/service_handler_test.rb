require 'assert'

require 'sanford/test_runner'

module Sanford::ServiceHandler

  class BaseTest < Assert::Context
    include Sanford::TestRunner::Helpers

    desc "Sanford::ServiceHandler"
    setup do
      @handler = test_runner(TestServiceHandler).handler
    end
    subject{ @handler }

    should have_instance_methods :init, :init!, :run, :run!

    should "raise a NotImplementedError if run! is not overwritten" do
      assert_raises(NotImplementedError){ subject.run! }
    end

  end

  class WithMethodFlagsTest < BaseTest
    setup do
      @handler = test_runner(FlagServiceHandler).handler
    end

    should "have called `init!` and it's callbacks" do
      assert_equal true, subject.before_init_called
      assert_equal true, subject.init_bang_called
      assert_equal true, subject.after_init_called
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
      runner = test_runner(HaltServiceHandler, {
        'code'    => 648,
        'data'    => true
      })
      runner.run

      assert_equal 648,   runner.response.code
      assert_equal true,  runner.response.data
      assert_nil runner.response.status.message
    end

    should "return a response with the status code for the named status and the passed message" do
      runner = test_runner(HaltServiceHandler, {
        'code'    => 'ok',
        'message' => 'test message'
      })
      runner.run

      assert_equal 200,             runner.response.code
      assert_equal 'test message',  runner.response.status.message
      assert_nil runner.response.data
    end

  end

  class HaltingTest < BaseTest
    desc "halting at different points"

    should "not call `init!, `after_init`, `run!` or run's callbacks when `before_init` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'before_init'
      })
      response = runner.response

      assert_equal true,  response.data[:before_init_called]
      assert_equal nil,   response.data[:init_bang_called]
      assert_equal nil,   response.data[:after_init_called]
      assert_equal nil,   response.data[:before_run_called]
      assert_equal nil,   response.data[:run_bang_called]
      assert_equal nil,   response.data[:after_run_called]

      assert_equal 'before_init halting', response.status.message
    end

    should "not call `after_init`, `run!` or it's callbacks when `init!` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'init!'
      })
      response = runner.response

      assert_equal true,  response.data[:before_init_called]
      assert_equal true,  response.data[:init_bang_called]
      assert_equal nil,   response.data[:after_init_called]
      assert_equal nil,   response.data[:before_run_called]
      assert_equal nil,   response.data[:run_bang_called]
      assert_equal nil,   response.data[:after_run_called]

      assert_equal 'init! halting', response.status.message
    end

    should "not call `run!` or it's callbacks when `after_init` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'after_init'
      })
      response = runner.response

      assert_equal true,  response.data[:before_init_called]
      assert_equal true,  response.data[:init_bang_called]
      assert_equal true,  response.data[:after_init_called]
      assert_equal nil,   response.data[:before_run_called]
      assert_equal nil,   response.data[:run_bang_called]
      assert_equal nil,   response.data[:after_run_called]

      assert_equal 'after_init halting', response.status.message
    end

    should "not call `run!` or `after_run` when `before_run` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'before_run'
      })
      response = runner.run

      assert_equal true,  response.data[:before_init_called]
      assert_equal true,  response.data[:init_bang_called]
      assert_equal true,  response.data[:after_init_called]
      assert_equal true,  response.data[:before_run_called]
      assert_equal nil,   response.data[:run_bang_called]
      assert_equal nil,   response.data[:after_run_called]

      assert_equal 'before_run halting', runner.response.status.message
    end

    should "not call `after_run` when `run!` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'run!'
      })
      response = runner.run

      assert_equal true,  response.data[:before_init_called]
      assert_equal true,  response.data[:init_bang_called]
      assert_equal true,  response.data[:after_init_called]
      assert_equal true,  response.data[:before_run_called]
      assert_equal true,  response.data[:run_bang_called]
      assert_equal nil,   response.data[:after_run_called]

      assert_equal 'run! halting', runner.response.status.message
    end

    should "call `init`, `run` and their callbacks when `after_run` halts" do
      runner = test_runner(HaltingBehaviorServiceHandler, {
        'when' => 'after_run'
      })
      response = runner.run

      assert_equal true,  response.data[:before_init_called]
      assert_equal true,  response.data[:init_bang_called]
      assert_equal true,  response.data[:after_init_called]
      assert_equal true,  response.data[:before_run_called]
      assert_equal true,  response.data[:run_bang_called]
      assert_equal true,  response.data[:after_run_called]

      assert_equal 'after_run halting', runner.response.status.message
    end

  end

end
