require 'benchmark'
require 'sanford-protocol'
require 'sanford/error_handler'
require 'sanford/logger'

module Sanford

  class ConnectionHandler

    attr_reader :server_data, :connection
    attr_reader :logger

    def initialize(server_data, connection)
      @server_data = server_data
      @connection = connection
      @logger = Sanford::Logger.new(
        @server_data.logger,
        @server_data.verbose_logging
      )
    end

    def run
      processed_service = nil
      self.log_received
      benchmark = Benchmark.measure do
        processed_service = self.run!
      end
      processed_service.time_taken = RoundedTime.new(benchmark.real)
      self.log_complete(processed_service)
      self.raise_if_debugging!(processed_service.exception)
      processed_service
    end

    protected

    def run!
      processed_service = ProcessedService.new
      begin
        request = Sanford::Protocol::Request.parse(@connection.read_data)
        self.log_request(request)
        processed_service.request = request

        route = @server_data.route_for(request.name)
        self.log_handler_class(route.handler_class)
        processed_service.handler_class = route.handler_class

        response = route.run(request, @server_data)
        processed_service.response = response
      rescue StandardError => exception
        self.handle_exception(exception, @server_data, processed_service)
      ensure
        self.write_response(processed_service)
      end
      processed_service
    end

    def write_response(processed_service)
      begin
        @connection.write_data processed_service.response.to_hash
      rescue StandardError => exception
        processed_service = self.handle_exception(
          exception,
          @server_data,
          processed_service
        )
        @connection.write_data processed_service.response.to_hash
      end
      @connection.close_write
      processed_service
    end

    def handle_exception(exception, server_data, processed_service)
      error_handler = Sanford::ErrorHandler.new(exception, {
        :server_data   => server_data,
        :request       => processed_service.request,
        :handler_class => processed_service.handler_class,
        :response      => processed_service.response
      })
      processed_service.response  = error_handler.run
      processed_service.exception = error_handler.exception
      self.log_exception(processed_service.exception)
      processed_service
    end

    def raise_if_debugging!(exception)
      raise exception if exception && ENV['SANFORD_DEBUG']
    end

    def log_received
      log_verbose "===== Received request ====="
    end

    def log_request(request)
      log_verbose "  Service: #{request.name.inspect}"
      log_verbose "  Params:  #{request.params.inspect}"
    end

    def log_handler_class(handler_class)
      log_verbose "  Handler: #{handler_class}"
    end

    def log_complete(processed_service)
      log_verbose "===== Completed in #{processed_service.time_taken}ms " \
                  "#{processed_service.response.status} ====="
      log_summary build_summary_line(processed_service)
    end

    def log_exception(exception)
      backtrace = exception.backtrace.join("\n")
      message = "#{exception.class}: #{exception.message}\n#{backtrace}"
      log_verbose(message, :error)
    end

    def log_verbose(message, level = :info)
      self.logger.verbose.send(level, "[Sanford] #{message}")
    end

    def log_summary(message, level = :info)
      self.logger.summary.send(level, "[Sanford] #{message}")
    end

    def build_summary_line(processed_service)
      summary_line_args = {
        'time'    => processed_service.time_taken,
        'handler' => processed_service.handler_class
      }
      if (request = processed_service.request)
        summary_line_args['service'] = request.name
        summary_line_args['params']  = request.params.to_hash
      end
      if (response = processed_service.response)
        summary_line_args['status'] = response.code
      end
      if (exception = processed_service.exception)
        summary_line_args['error'] = "#{exception.class}: #{exception.message}"
      end
      SummaryLine.new(summary_line_args)
    end

    module SummaryLine
      KEYS = %w{time status handler service params error}.freeze

      def self.new(line_attrs)
        KEYS.map{ |k| "#{k}=#{line_attrs[k].inspect}" }.join(' ')
      end
    end

    module RoundedTime
      ROUND_PRECISION = 2
      ROUND_MODIFIER = 10 ** ROUND_PRECISION
      def self.new(time_in_seconds)
        (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
      end
    end

    ProcessedService = Struct.new(
      :request, :handler_class, :response, :exception, :time_taken
    )

  end

end
