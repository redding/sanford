require 'assert'
require 'sanford/sanford_runner'

require 'sanford/server_data'
require 'sanford/service_handler'

class Sanford::SanfordRunner

  class UnitTests < Assert::Context
    desc "Sanford::SanfordRunner"
    setup do
      @handler_class = TestServiceHandler
      @request = Sanford::Protocol::Request.new(Factory.string, {
        :something => Factory.string
      })
      @server_data = Sanford::ServerData.new({
        :logger => Factory.string,
        :template_source => Factory.string
      })

      @runner_class = Sanford::SanfordRunner
    end
    subject{ @runner_class }

    should "be a runner" do
      assert_true subject < Sanford::Runner
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class, @request, @server_data)
    end
    subject{ @runner }

    should "know its request, params, logger and template source" do
      assert_equal @request, subject.request
      assert_equal @request.params, subject.params
      assert_equal @server_data.logger, subject.logger
      assert_equal @server_data.template_source, subject.template_source
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @handler = @runner.handler
      @response = @runner.run
    end
    subject{ @response }

    should "run the handlers before callbacks" do
      assert_equal 1, @handler.first_before_call_order
      assert_equal 2, @handler.second_before_call_order
    end

    should "run the handlers init" do
      assert_equal 3, @handler.init_call_order
    end

    should "run the handlers run and use its result to build a response" do
      assert_equal 4, @handler.run_call_order
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @handler.response_data, subject.data
    end

    should "run the handlers after callbacks" do
      assert_equal 5, @handler.first_after_call_order
      assert_equal 6, @handler.second_after_call_order
    end

  end

  class RunHaltInBeforeTests < UnitTests
    desc "running a handler that halts in a before callback"
    setup do
      req = Sanford::Protocol::Request.new(Factory.string, 'halt' => 'before')
      runner = @runner_class.new(@handler_class, req, @server_data).tap(&:run)
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

  class RunHandlerHaltInitTests < UnitTests
    desc "running a handler that halts in init"
    setup do
      req = Sanford::Protocol::Request.new(Factory.string, 'halt' => 'init')
      runner = @runner_class.new(@handler_class, req, @server_data).tap(&:run)
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

  class RunHandlerHaltRunTests < UnitTests
    desc "running a handler that halts in run"
    setup do
      req = Sanford::Protocol::Request.new(Factory.string, 'halt' => 'run')
      runner = @runner_class.new(@handler_class, req, @server_data).tap(&:run)
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

  class RunHandlerHaltAfterTests < UnitTests
    desc "running a handler that halts in a after callback"
    setup do
      req = Sanford::Protocol::Request.new(Factory.string, 'halt' => 'after')
      runner = @runner_class.new(@handler_class, req, @server_data).tap(&:run)
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

    before do
      @first_before_call_order = next_call_order
      halt_if('before')
    end
    before{ @second_before_call_order = next_call_order }

    after do
      @first_after_call_order = next_call_order
      halt_if('after')
    end
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

    def next_call_order
      @order ||= 0
      @order += 1
    end

    def halt_if(value)
      halt Factory.integer if params['halt'] == value
    end
  end

end
