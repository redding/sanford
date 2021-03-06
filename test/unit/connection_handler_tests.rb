require 'assert'
require 'sanford/connection_handler'

require 'sanford/route'
require 'sanford/server_data'
require 'test/support/fake_server_connection'

class Sanford::ConnectionHandler

  class UnitTests < Assert::Context
    desc "Sanford::ConnectionHandler"
    setup do
      @route = Sanford::Route.new(Factory.string, TestHandler.to_s).tap(&:validate!)
      @server_data = Sanford::ServerData.new({
        :logger => Sanford::NullLogger.new,
        :verbose_logging => Factory.boolean,
        :routes => [ @route ]
      })
      @connection = FakeServerConnection.with_request(@route.name)
      @request = @connection.request
      @response = Sanford::Protocol::Response.new(Factory.integer, Factory.string)
      @exception = RuntimeError.new(Factory.string)

      @handler_class = Sanford::ConnectionHandler
    end
    subject{ @handler_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @connection_handler = @handler_class.new(@server_data, @connection)
    end
    subject{ @connection_handler }

    should have_readers :server_data, :connection
    should have_readers :logger
    should have_imeths :run

    should "know its server data and connection" do
      assert_equal @server_data, subject.server_data
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

      @processed_service = @connection_handler.run
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
      assert_includes @server_data, @route_called_with
    end

    should "have written the response to the connection" do
      assert_equal @response, @connection.response
      assert_true @connection.write_closed
    end

  end

  class RunWithExceptionSetupTests < InitTests
    setup do
      @route_exception = Factory.sanford_std_error
      Assert.stub(@route, :run){ raise @route_exception }
      Assert.stub(Sanford::ErrorHandler, :new) do |*args|
        @error_handler_spy = ErrorHandlerSpy.new(*args)
      end
    end

  end

  class RunWithExceptionTests < RunWithExceptionSetupTests
    desc "and run with an exception"
    setup do
      @processed_service = @connection_handler.run
    end

    should "run an error handler" do
      assert_equal @route_exception, @error_handler_spy.passed_exception
      exp = {
        :server_data   => @server_data,
        :request       => @processed_service.request,
        :handler_class => @processed_service.handler_class,
        :response      => nil
      }
      assert_equal exp, @error_handler_spy.context_hash
      assert_true @error_handler_spy.run_called
    end

    should "store the error handler response and exception on the processed service" do
      assert_equal @error_handler_spy.response,  @processed_service.response
      assert_equal @error_handler_spy.exception, @processed_service.exception
    end

    should "write the error response to the connection" do
      assert_equal @error_handler_spy.response, @connection.response
      assert_true @connection.write_closed
    end

  end

  class RunWithShutdownErrorTests < RunWithExceptionSetupTests
    desc "and run with a dat worker pool shutdown error"
    setup do
      @shutdown_error = DatWorkerPool::ShutdownError.new(Factory.text)
      Assert.stub(@route, :run){ raise @shutdown_error }
    end

    should "run an error handler" do
      assert_raises{ @connection_handler.run }

      passed_exception = @error_handler_spy.passed_exception
      assert_instance_of Sanford::ShutdownError, passed_exception
      assert_equal @shutdown_error.message, passed_exception.message
      assert_equal @shutdown_error.backtrace, passed_exception.backtrace
      assert_true @error_handler_spy.run_called
    end

    should "raise the shutdown error" do
      assert_raises(@shutdown_error.class){ @connection_handler.run }
    end

  end

  class RunWithExceptionWhileWritingTests < RunWithExceptionSetupTests
    desc "and run with an exception thrown while writing the response"
    setup do
      Assert.stub(@route, :run){ @response }
      @connection.raise_on_write = true

      @processed_service = @connection_handler.run
    end
    subject{ @processed_service }

    should "run an error handler" do
      assert_equal @connection.write_exception, @error_handler_spy.passed_exception
      exp = {
        :server_data   => @server_data,
        :request       => @processed_service.request,
        :handler_class => @processed_service.handler_class,
        :response      => @response
      }
      assert_equal exp, @error_handler_spy.context_hash
      assert_true @error_handler_spy.run_called
    end

    should "store the error handler response and exception on the processed service" do
      assert_equal @error_handler_spy.response,  @processed_service.response
      assert_equal @error_handler_spy.exception, @processed_service.exception
    end

    should "write the error response to the connection" do
      assert_equal @error_handler_spy.response, @connection.response
      assert_true @connection.write_closed
    end

  end

  class RunWithVerboseLoggingTests < UnitTests
    desc "run with verbose logging"
    setup do
      @spy_logger = SpyLogger.new
      @server_data = Sanford::ServerData.new({
        :logger => @spy_logger,
        :verbose_logging => true,
        :routes => [ @route ]
      })
      Assert.stub(@route, :run){ raise @exception }

      @connection_handler = @handler_class.new(@server_data, @connection)
      @processed_service = @connection_handler.run
    end
    subject{ @spy_logger }

    should "have logged the service" do
      time_taken = @processed_service.time_taken
      status = @processed_service.response.status.to_s
      exp = "[Sanford] ===== Received request =====" \
            "[Sanford]   Service: #{@request.name.inspect}" \
            "[Sanford]   Params:  #{@request.params.inspect}" \
            "[Sanford]   Handler: #{@route.handler_class}" \
            "[Sanford] ===== Completed in #{time_taken}ms #{status} ====="
      assert_equal exp, subject.info_logged.join
    end

    should "log an exception when one is thrown" do
      err = @processed_service.exception
      exp = "[Sanford] #{err.class}: #{err.message}"
      assert_equal exp, subject.error_logged.first
      err.backtrace.each do |l|
        assert_includes "[Sanford] #{l}", subject.error_logged
      end
    end

  end

  class RunWithSummaryLoggingTests < UnitTests
    desc "run with summary logging"
    setup do
      @spy_logger = SpyLogger.new
      @server_data = Sanford::ServerData.new({
        :logger => @spy_logger,
        :verbose_logging => false,
        :routes => [ @route ]
      })
      Assert.stub(@route, :run){ raise @exception }

      @connection_handler = @handler_class.new(@server_data, @connection)
      @processed_service = @connection_handler.run
    end
    subject{ @spy_logger }

    should "have logged the service" do
      time_taken = @processed_service.time_taken
      status = @processed_service.response.status.to_i
      exception_msg = "#{@exception.class}: #{@exception.message}"
      exp = "[Sanford] " \
            "time=#{time_taken} " \
            "status=#{status} " \
            "handler=#{@route.handler_class} " \
            "service=#{@request.name.inspect} " \
            "params=#{@request.params.inspect} " \
            "error=#{exception_msg.inspect}"
      assert_equal exp, subject.info_logged.join
    end

    should "not have logged the exception" do
      assert_empty @spy_logger.error_logged
    end

  end

  TestHandler = Class.new

  class ErrorHandlerSpy
    attr_reader :passed_exception, :context_hash, :exception, :response
    attr_reader :run_called

    def initialize(exception, context_hash)
      @passed_exception = exception
      @context_hash     = context_hash
      @exception        = Factory.sanford_std_error
      @response         = Factory.protocol_response
      @run_called       = false
    end

    def run
      @run_called = true
      @response
    end
  end

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
