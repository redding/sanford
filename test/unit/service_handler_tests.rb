require 'assert'
require 'sanford/service_handler'

require 'sanford/template_engine'
require 'sanford/template_source'
require 'sanford/test_runner'

module Sanford::ServiceHandler

  class UnitTests < Assert::Context
    include Sanford::ServiceHandler::TestHelpers

    desc "Sanford::ServiceHandler"
    setup do
      @handler_class = Class.new{ include Sanford::ServiceHandler }
    end
    subject{ @handler_class }

    should have_imeths :before_callbacks, :after_callbacks
    should have_imeths :before_init_callbacks, :after_init_callbacks
    should have_imeths :before_run_callbacks,  :after_run_callbacks
    should have_imeths :before, :after
    should have_imeths :before_init, :after_init
    should have_imeths :before_run,  :after_run
    should have_imeths :prepend_before, :prepend_after
    should have_imeths :prepend_before_init, :prepend_after_init
    should have_imeths :prepend_before_run,  :prepend_after_run

    should "return an empty array by default using `before_callbacks`" do
      assert_equal [], subject.before_callbacks
    end

    should "return an empty array by default using `after_callbacks`" do
      assert_equal [], subject.after_callbacks
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

    should "append a block to the before callbacks using `before`" do
      subject.before_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before(&block)
      assert_equal block, subject.before_callbacks.last
    end

    should "append a block to the after callbacks using `after`" do
      subject.after_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after(&block)
      assert_equal block, subject.after_callbacks.last
    end

    should "append a block to the before init callbacks using `before_init`" do
      subject.before_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before_init(&block)
      assert_equal block, subject.before_init_callbacks.last
    end

    should "append a block to the after init callbacks using `after_init`" do
      subject.after_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after_init(&block)
      assert_equal block, subject.after_init_callbacks.last
    end

    should "append a block to the before run callbacks using `before_run`" do
      subject.before_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.before_run(&block)
      assert_equal block, subject.before_run_callbacks.last
    end

    should "append a block to the after run callbacks using `after_run`" do
      subject.after_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.after_run(&block)
      assert_equal block, subject.after_run_callbacks.last
    end

    should "prepend a block to the before callbacks using `prepend_before`" do
      subject.before_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before(&block)
      assert_equal block, subject.before_callbacks.first
    end

    should "prepend a block to the after callbacks using `prepend_after`" do
      subject.after_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after(&block)
      assert_equal block, subject.after_callbacks.first
    end

    should "prepend a block to the before init callbacks using `prepend_before_init`" do
      subject.before_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before_init(&block)
      assert_equal block, subject.before_init_callbacks.first
    end

    should "prepend a block to the after init callbacks using `prepend_after_init`" do
      subject.after_init_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after_init(&block)
      assert_equal block, subject.after_init_callbacks.first
    end

    should "prepend a block to the before run callbacks using `prepend_before_run`" do
      subject.before_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_before_run(&block)
      assert_equal block, subject.before_run_callbacks.first
    end

    should "prepend a block to the after run callbacks using `prepend_after_run`" do
      subject.after_run_callbacks << proc{ Factory.string }
      block = Proc.new{ Factory.string }
      subject.prepend_after_run(&block)
      assert_equal block, subject.after_run_callbacks.first
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner  = test_runner(TestServiceHandler)
      @handler = @runner.handler
    end
    subject{ @handler }

    should have_imeths :sanford_init, :init!, :sanford_run, :run!
    should have_imeths :sanford_run_callback

    should "have called `init!` and its before/after init callbacks" do
      assert_equal 1, subject.first_before_init_call_order
      assert_equal 2, subject.second_before_init_call_order
      assert_equal 3, subject.init_call_order
      assert_equal 4, subject.first_after_init_call_order
      assert_equal 5, subject.second_after_init_call_order
    end

    should "not have called `run!` and its before/after run callbacks" do
      assert_nil subject.first_before_run_call_order
      assert_nil subject.second_before_run_call_order
      assert_nil subject.run_call_order
      assert_nil subject.first_after_run_call_order
      assert_nil subject.second_after_run_call_order
    end

    should "run its callbacks with `sanford_run_callback`" do
      subject.sanford_run_callback 'before_run'
      assert_equal 6, subject.first_before_run_call_order
      assert_equal 7, subject.second_before_run_call_order
    end

    should "know if it is equal to another service handler" do
      handler = test_handler(TestServiceHandler)
      assert_equal handler, subject

      handler = test_handler(Class.new{ include Sanford::ServiceHandler })
      assert_not_equal handler, subject
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @handler.sanford_run
    end

    should "call `run!` and it's callbacks" do
      assert_equal 6,  subject.first_before_run_call_order
      assert_equal 7,  subject.second_before_run_call_order
      assert_equal 8,  subject.run_call_order
      assert_equal 9,  subject.first_after_run_call_order
      assert_equal 10, subject.second_after_run_call_order
    end

  end

  class PrivateHelpersTests < InitTests
    setup do
      @something = Factory.string
      @args      = (Factory.integer(3)+1).times.map{ Factory.string }
    end

    should "call to the runner for its logger" do
      stub_runner_with_something_for(:logger)
      assert_equal @runner.logger, subject.instance_eval{ logger }
    end

    should "call to the runner for its request" do
      stub_runner_with_something_for(:request)
      assert_equal @runner.request, subject.instance_eval{ request }
    end

    should "call to the runner for its params" do
      stub_runner_with_something_for(:params)
      assert_equal @runner.params, subject.instance_eval{ params }
    end

    should "call to the runner for its status helper" do
      capture_runner_meth_args_for(:status)
      exp_args = @args
      subject.instance_eval{ status(*exp_args) }

      assert_equal exp_args, @meth_args
      assert_nil @meth_block
    end

    should "call to the runner for its data helper" do
      capture_runner_meth_args_for(:data)
      exp_args = @args
      subject.instance_eval{ data(*exp_args) }

      assert_equal exp_args, @meth_args
      assert_nil @meth_block
    end

    should "call to the runner for its halt helper" do
      capture_runner_meth_args_for(:halt)
      exp_args = @args
      subject.instance_eval{ halt(*exp_args) }

      assert_equal exp_args, @meth_args
    end

    should "call to the runner for its render helper" do
      capture_runner_meth_args_for(:render)
      exp_args = @args
      subject.instance_eval{ render(*exp_args) }

      assert_equal exp_args, @meth_args
    end

    private

    def stub_runner_with_something_for(meth)
      Assert.stub(@runner, meth){ @something }
    end

    def capture_runner_meth_args_for(meth)
      Assert.stub(@runner, meth) do |*args|
        @meth_args = args
      end
    end

  end

  class TestHelpersTests < UnitTests
    desc "TestHelpers"
    setup do
      context_class = Class.new{ include Sanford::ServiceHandler::TestHelpers }
      @context = context_class.new
    end
    subject{ @context }

    should have_imeths :test_runner, :test_handler

    should "build a test runner for a given handler class" do
      runner  = subject.test_runner(@handler_class)

      assert_kind_of ::Sanford::TestRunner, runner
      assert_equal @handler_class, runner.handler_class
    end

    should "return an initialized handler instance" do
      handler = subject.test_handler(@handler_class)
      assert_kind_of @handler_class, handler

      exp = subject.test_runner(@handler_class).handler
      assert_equal exp, handler
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

    attr_reader :first_before_init_call_order, :second_before_init_call_order
    attr_reader :first_after_init_call_order, :second_after_init_call_order
    attr_reader :first_before_run_call_order, :second_before_run_call_order
    attr_reader :first_after_run_call_order, :second_after_run_call_order
    attr_reader :init_call_order, :run_call_order

    before_init{ @first_before_init_call_order = next_call_order }
    before_init{ @second_before_init_call_order = next_call_order }

    after_init{ @first_after_init_call_order = next_call_order }
    after_init{ @second_after_init_call_order = next_call_order }

    before_run{ @first_before_run_call_order = next_call_order }
    before_run{ @second_before_run_call_order = next_call_order }

    after_run{ @first_after_run_call_order = next_call_order }
    after_run{ @second_after_run_call_order = next_call_order }

    def init!
      @init_call_order = next_call_order
    end

    def run!
      @run_call_order = next_call_order
    end

    private

    def next_call_order
      @order ||= 0
      @order += 1
    end

  end

end
