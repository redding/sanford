require 'assert'
require 'sanford/sanford_runner'

require 'sanford/server_data'

class Sanford::SanfordRunner

  class UnitTests < Assert::Context
    desc "Sanford::SanfordRunner"
    setup do
      @handler_class = TestServiceHandler
      @request = Sanford::Protocol::Request.new(Factory.string, {})
      @server_data = Sanford::ServerData.new

      @runner_class = Sanford::SanfordRunner
    end
    subject{ @runner_class }

    should "be a runner" do
      assert_includes Sanford::Runner, subject
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class, @request, @server_data)
    end
    subject{ @runner }

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @handler = @runner.handler
      @response = @runner.run
    end
    subject{ @response }

    should "run the handlers before callbacks" do
      assert_equal 1, @handler.before_call_order
    end

    should "run the handlers init" do
      assert_equal 2, @handler.init_call_order
    end

    should "run the handlers run and use its result to build a response" do
      assert_equal 3, @handler.run_call_order
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @handler.response_data, subject.data
    end

    should "run the handlers after callbacks" do
      assert_equal 4, @handler.after_call_order
    end

  end

  class TestServiceHandler
    include Sanford::ServiceHandler

    attr_reader :before_call_order, :after_call_order
    attr_reader :init_call_order, :run_call_order
    attr_reader :response_data

    before{ @before_call_order = next_call_order }
    after{ @after_call_order = next_call_order }

    def init!
      @init_call_order = next_call_order
    end

    def run!
      @run_call_order = next_call_order
      @response_data ||= Factory.string
    end

    private

    def next_call_order
      @order ||= 0
      @order += 1
    end
  end

end
