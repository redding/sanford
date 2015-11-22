require 'assert'
require 'sanford/sanford_runner'

require 'sanford/runner'
require 'sanford/service_handler'

class Sanford::SanfordRunner

  class UnitTests < Assert::Context
    desc "Sanford::SanfordRunner"
    setup do
      @handler_class = TestServiceHandler
      @runner_class  = Sanford::SanfordRunner
    end
    subject{ @runner_class }

    should "be a runner" do
      assert_true subject < Sanford::Runner
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class)
    end
    subject{ @runner }

    should have_imeths :run

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @handler  = @runner.handler
      @response = @runner.run
    end
    subject{ @response }

    should "run the handler's before callbacks" do
      assert_equal 1, @handler.first_before_call_order
      assert_equal 2, @handler.second_before_call_order
    end

    should "run the handler's init and run methods" do
      assert_equal 3, @handler.init_call_order
      assert_equal 4, @handler.run_call_order
    end

    should "run the handler's after callbacks" do
      assert_equal 5, @handler.first_after_call_order
      assert_equal 6, @handler.second_after_call_order
    end

    should "build a response" do
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @handler.response_data, subject.data
    end

  end

  class RunWithInitHaltTests < UnitTests
    desc "with a handler that halts on init"
    setup do
      runner = @runner_class.new(@handler_class, :params => {
        'halt' => 'init'
      }).tap(&:run)
      @handler = runner.handler
    end
    subject{ @handler }

    should "stop processing when the halt is called" do
      assert_not_nil subject.first_before_call_order
      assert_not_nil subject.second_before_call_order
      assert_not_nil subject.init_call_order
      assert_nil subject.run_call_order
      assert_nil subject.first_after_call_order
      assert_nil subject.second_after_call_order
    end

  end

  class RunWithRunHaltTests < UnitTests
    desc "when run with a handler that halts on run"
    setup do
      runner = @runner_class.new(@handler_class, :params => {
        'halt' => 'run'
      }).tap(&:run)
      @handler = runner.handler
    end
    subject{ @handler }

    should "stop processing when the halt is called" do
      assert_not_nil subject.first_before_call_order
      assert_not_nil subject.second_before_call_order
      assert_not_nil subject.init_call_order
      assert_not_nil subject.run_call_order
      assert_nil subject.first_after_call_order
      assert_nil subject.second_after_call_order
    end

  end

  class RunWithBeforeHaltTests < UnitTests
    desc "when run with a handler that halts in an after callback"
    setup do
      runner = @runner_class.new(@handler_class, :params => {
        'halt' => 'before'
      }).tap(&:run)
      @handler = runner.handler
    end
    subject{ @handler }

    should "stop processing when the halt is called" do
      assert_not_nil subject.first_before_call_order
      assert_nil subject.second_before_call_order
      assert_nil subject.init_call_order
      assert_nil subject.run_call_order
      assert_nil subject.first_after_call_order
      assert_nil subject.second_after_call_order
    end

  end

  class RunWithAfterHaltTests < UnitTests
    desc "when run with a handler that halts in an after callback"
    setup do
      runner = @runner_class.new(@handler_class, :params => {
        'halt' => 'after'
      }).tap(&:run)
      @handler = runner.handler
    end
    subject{ @handler }

    should "stop processing when the halt is called" do
      assert_not_nil subject.first_before_call_order
      assert_not_nil subject.second_before_call_order
      assert_not_nil subject.init_call_order
      assert_not_nil subject.run_call_order
      assert_not_nil subject.first_after_call_order
      assert_nil subject.second_after_call_order
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

    attr_reader :first_before_call_order, :second_before_call_order
    attr_reader :first_after_call_order, :second_after_call_order
    attr_reader :init_call_order, :run_call_order
    attr_reader :response_data

    before{ @first_before_call_order = next_call_order; halt_if('before') }
    before{ @second_before_call_order = next_call_order }

    after{ @first_after_call_order = next_call_order; halt_if('after') }
    after{ @second_after_call_order = next_call_order }

    def init!
      @init_call_order = next_call_order
      halt_if('init')
    end

    def run!
      @run_call_order = next_call_order
      halt_if('run')
      @response_data ||= Factory.string
    end

    private

    def next_call_order; @order ||= 0; @order += 1; end

    def halt_if(value)
      halt Factory.integer if params['halt'] == value
    end

  end

end
