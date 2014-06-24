require 'assert'
require 'sanford/runner'

require 'sanford/server_data'
require 'sanford/service_handler'

module Sanford::Runner

  class UnitTests < Assert::Context
    desc "Sanford::Runner"
    setup do
      @handler_class = TestServiceHandler
      @request = Sanford::Protocol::Request.new(Factory.string, {})
      @server_data = Sanford::ServerData.new({
        :logger => Factory.string,
        :template_source => Factory.string
      })

      @runner_class = TestRunner
    end
    subject{ @runner_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @runner = @runner_class.new(@handler_class, @request, @server_data)
    end
    subject{ @runner }

    should have_readers :handler_class, :request
    should have_readers :logger, :template_source
    should have_readers :handler
    should have_imeths :run, :run!
    should have_imeths :halt

    should "know its handler class, request, logger and template source" do
      assert_equal @handler_class, subject.handler_class
      assert_equal @request, subject.request
      assert_equal @server_data.logger, subject.logger
      assert_equal @server_data.template_source, subject.template_source
    end

    should "build an instance of its handler class" do
      assert_instance_of @handler_class, subject.handler
    end

    should "throw halt with response args using `halt`" do
      code = Factory.integer
      message = Factory.string
      data = Factory.string

      result = catch(:halt) do
        subject.halt(code, :message => message, :data => data)
      end
      assert_instance_of ResponseArgs, result
      assert_equal [ code, message ], result.status
      assert_equal data, result.data
    end

    should "accept string keys using `halt`" do
      code = Factory.integer
      message = Factory.string
      data = Factory.string

      result = catch(:halt) do
        subject.halt(code, 'message' => message, 'data' => data)
      end
      assert_instance_of ResponseArgs, result
      assert_equal [ code, message ], result.status
      assert_equal data, result.data
    end

    should "raise a not implemented error when run by default" do
      runner_class = Class.new{ include Sanford::Runner }
      runner = runner_class.new(@handler_class, @request, @server_data)
      assert_raises(NotImplementedError){ runner.run }
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @response = @runner.run
    end
    subject{ @response }

    should "return a protocol response from the run! return-value" do
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @runner.run_return_code, subject.code
      assert_equal @runner.run_return_data, subject.data
    end

  end

  class RunThatHaltsTests < UnitTests
    desc "that halts is run"
    setup do
      @runner = HaltRunner.new(@handler_class, @request, @server_data)
      @response = @runner.run
    end
    subject{ @response }

    should "return a protocol response from the halt args" do
      assert_instance_of Sanford::Protocol::Response, subject
      assert_equal @runner.halt_code, subject.code
      assert_equal @runner.halt_options[:message], subject.status.message
      assert_equal @runner.halt_options[:data], subject.data
    end

  end

  class TestRunner
    include Sanford::Runner

    attr_reader :run_return_code, :run_return_data

    def run!
      @run_return_code ||= Factory.integer
      @run_return_data ||= Factory.string
      [ @run_return_code, @run_return_data ]
    end
  end

  class HaltRunner
    include Sanford::Runner

    attr_reader :halt_code, :halt_options

    def run!
      @halt_code ||= Factory.integer
      @halt_options ||= { :message => Factory.string, :data => Factory.string }
      halt(@halt_code, @halt_options)
    end
  end

  class TestServiceHandler
    include Sanford::ServiceHandler
  end

end
