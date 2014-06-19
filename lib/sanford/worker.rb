require 'benchmark'
require 'sanford-protocol'
require 'sanford/error_handler'
require 'sanford/logger'
require 'sanford/runner'

module Sanford

  class Worker

    ProcessedService = Struct.new(
      :request, :handler_class, :response, :exception, :time_taken
    )

    attr_reader :config_data, :connection
    attr_reader :logger

    def initialize(config_data, connection)
      @config_data = config_data
      @connection = connection
      @logger = Sanford::Logger.new(
        @config_data.logger,
        @config_data.verbose_logging
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
      service = ProcessedService.new
      begin
        request = Sanford::Protocol::Request.parse(@connection.read_data)
        self.log_request(request)
        service.request = request

        route = @config_data.route_for(request.name)
        self.log_handler_class(route.handler_class)
        service.handler_class = route.handler_class

        response = route.run(request, @config_data.logger)
        service.response = response
      rescue StandardError => exception
        self.handle_exception(service, exception, @config_data)
      ensure
        self.write_response(service)
      end
      service
    end

    def write_response(service)
      begin
        @connection.write_data service.response.to_hash
      rescue StandardError => exception
        service = self.handle_exception(service, exception)
        @connection.write_data service.response.to_hash
      end
      @connection.close_write
      service
    end

    def handle_exception(service, exception, config_data = nil)
      error_handler = Sanford::ErrorHandler.new(
        exception,
        config_data,
        service.request
      )
      service.response  = error_handler.run
      service.exception = error_handler.exception
      self.log_exception(service.exception)
      service
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
      summary_line_args = {
        'time'    => processed_service.time_taken,
        'handler' => processed_service.handler_class
      }
      if processed_service.response
        summary_line_args['status'] = processed_service.response.code
      end
      if (request = processed_service.request)
        summary_line_args['service'] = request.name
        summary_line_args['params']  = request.params
      end
      log_summary SummaryLine.new(summary_line_args)
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

    module RoundedTime
      ROUND_PRECISION = 2
      ROUND_MODIFIER = 10 ** ROUND_PRECISION
      def self.new(time_in_seconds)
        (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
      end
    end

    module SummaryLine
      def self.new(line_attrs)
        attr_keys = %w{time status handler service params}
        attr_keys.map{ |k| "#{k}=#{line_attrs[k].inspect}" }.join(' ')
      end
    end

  end

end
