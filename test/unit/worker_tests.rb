require 'assert'
require 'sanford/worker'

require 'sanford/route'
require 'sanford/server'
require 'test/support/fake_connection'

class Sanford::Worker

  class UnitTests < Assert::Context
    desc "Sanford::Worker"
    setup do
      @route = Sanford::Route.new(Factory.string, TestHandler.to_s).tap(&:validate!)
      @config_data = Sanford::Server::ConfigData.new({
        :logger => Sanford::NullLogger.new,
        :verbose_logging => Factory.boolean,
        :routes => [ @route ]
      })
      @connection = FakeConnection.with_request(@route.name, {})
      @request = @connection.request
      @response = Sanford::Protocol::Response.new(Factory.integer, Factory.string)
      @exception = RuntimeError.new(Factory.string)

      @worker_class = Sanford::Worker
    end
    subject{ @worker_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @worker = @worker_class.new(@config_data, @connection)
    end
    subject{ @worker }

    should have_readers :config_data, :connection
    should have_readers :logger
    should have_imeths :run

    should "know its config data and connection" do
      assert_equal @config_data, subject.config_data
      assert_equal @connection, subject.connection
    end

    should "know its logger" do
      assert_instance_of Sanford::Logger, subject.logger
    end

  end

  class RunTests < InitTests
    desc "and run"
    setup do
      @route_called_with = nil
      Assert.stub(@route, :run) do |*args|
        @route_called_with = args
        @response
      end

      @processed_service = @worker.run
    end
    subject{ @processed_service }

    should "return a processed service" do
      assert_instance_of ProcessedService, subject
      assert_equal @request, subject.request
      assert_equal @route.handler_class, subject.handler_class
      assert_equal @response, subject.response
      assert_nil subject.exception
      assert_not_nil subject.time_taken
    end

    should "run the route" do
      assert_not_nil @route_called_with
      assert_includes @request, @route_called_with
      assert_includes @config_data.logger, @route_called_with
    end

    should "have written the response to the connection" do
      assert_equal @response, @connection.response
      assert_true @connection.write_stream_closed
    end

  end

  class RunWithExceptionTests < InitTests
    desc "and run with a route that throws an exception"
    setup do
      Assert.stub(@route, :run){ raise @exception }

      error_handler = Sanford::ErrorHandler.new(
        @exception,
        @config_data,
        @request
      )
      @expected_response = error_handler.run
      @expected_exception = error_handler.exception

      @processed_service = @worker.run
    end
    subject{ @processed_service }

    should "return a processed service with an exception" do
      assert_instance_of ProcessedService, subject
      assert_equal @expected_response,  subject.response
      assert_equal @expected_exception, subject.exception
    end

    should "have written the error response to the connection" do
      assert_equal @expected_response, @connection.response
      assert_true @connection.write_stream_closed
    end

  end

  class RunWithExceptionWhileWritingTests < InitTests
    desc "and run with an exception thrown while writing the response"
    setup do
      Assert.stub(@route, :run){ @response }

      @connection.raise_on_write = true

      error_handler = Sanford::ErrorHandler.new(
        @connection.write_exception,
        @config_data,
        @request
      )
      @expected_response = error_handler.run
      @expected_exception = error_handler.exception

      @processed_service = @worker.run
    end
    subject{ @processed_service }

    should "return a processed service with an exception" do
      assert_instance_of ProcessedService, subject
      assert_equal @expected_response,  subject.response
      assert_equal @expected_exception, subject.exception
    end

    should "have written the error response to the connection" do
      assert_equal @expected_response, @connection.response
      assert_true @connection.write_stream_closed
    end

  end

  class RunWithExceptionWhileDebuggingTests < InitTests
    desc "and run with a route that throws an exception in debug mode"
    setup do
      ENV['SANFORD_DEBUG'] = '1'
      Assert.stub(@route, :run){ raise @exception }
    end
    teardown do
      ENV.delete('SANFORD_DEBUG')
    end

    should "raise the exception" do
      assert_raises(@exception.class){ @worker.run }
    end

  end

  class RunWithVerboseLoggingTests < UnitTests
    desc "run with verbose logging"
    setup do
      @spy_logger = SpyLogger.new
      @config_data = Sanford::Server::ConfigData.new({
        :logger => @spy_logger,
        :verbose_logging => true,
        :routes => [ @route ]
      })
      Assert.stub(@route, :run){ raise @exception }

      @worker = @worker_class.new(@config_data, @connection)
      @processed_service = @worker.run
    end
    subject{ @spy_logger }

    should "have logged the service" do
      time_taken = @processed_service.time_taken
      status = @processed_service.response.status.to_s
      expected = "[Sanford] ===== Received request =====" \
                 "[Sanford]   Service: #{@request.name.inspect}" \
                 "[Sanford]   Params:  #{@request.params.inspect}" \
                 "[Sanford]   Handler: #{@route.handler_class}" \
                 "[Sanford] ===== Completed in #{time_taken}ms #{status} ====="
      assert_equal expected, subject.info_logged.join
    end

    should "log an exception when one is thrown" do
      err = @processed_service.exception
      backtrace = err.backtrace.join("\n")
      expected = "[Sanford] #{err.class}: #{err.message}\n#{backtrace}"
      assert_equal expected, subject.error_logged.join
    end

  end

  class RunWithSummaryLoggingTests < UnitTests
    desc "run with summary logging"
    setup do
      @spy_logger = SpyLogger.new
      @config_data = Sanford::Server::ConfigData.new({
        :logger => @spy_logger,
        :verbose_logging => false,
        :routes => [ @route ]
      })
      Assert.stub(@route, :run){ raise @exception }

      @worker = @worker_class.new(@config_data, @connection)
      @processed_service = @worker.run
    end
    subject{ @spy_logger }

    should "have logged the service" do
      time_taken = @processed_service.time_taken
      status = @processed_service.response.status.to_i
      expected = "[Sanford] " \
                 "time=#{time_taken} " \
                 "status=#{status} " \
                 "handler=#{@route.handler_class} " \
                 "service=#{@request.name.inspect} " \
                 "params=#{@request.params.inspect}"
      assert_equal expected, subject.info_logged.join
    end

    should "not have logged the exception" do
      assert_empty @spy_logger.error_logged
    end

  end

  TestHandler = Class.new

  class SpyLogger
    attr_reader :info_logged, :error_logged

    def initialize
      @info_logged = []
      @error_logged = []
    end

    def info(message)
      @info_logged << message
    end

    def error(message)
      @error_logged << message
    end
  end

end
