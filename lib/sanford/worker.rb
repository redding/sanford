require 'benchmark'
require 'sanford-protocol'

require 'sanford/error_handler'
require 'sanford/logger'
require 'sanford/runner'

module Sanford

  class Worker

    ProcessedService = Struct.new(:request, :handler_class, :response, :exception, :time_taken)

    attr_reader :logger

    def initialize(host_data, connection)
      @host_data, @connection = host_data, connection

      @logger = Sanford::Logger.new(@host_data.logger, @host_data.verbose)
    end

    def run
      processed_service = nil
      self.log_received
      benchmark = Benchmark.measure do
        processed_service = self.run!
      end
      processed_service.time_taken = self.round_time(benchmark.real)
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

        handler_class = @host_data.handler_class_for(request.version, request.name)
        self.log_handler_class(handler_class)
        service.handler_class = handler_class

        response = Sanford::Runner.new(handler_class, request, @host_data.logger).run
        service.response = response
      rescue Exception => exception
        self.handle_exception(service, exception, @host_data)
      ensure
        self.write_response(service)
      end
      service
    end

    def write_response(service)
      begin
        @connection.write_data service.response.to_hash
      rescue Exception => exception
        service = self.handle_exception(service, exception)
        @connection.write_data service.response.to_hash
      end
      service
    end

    def handle_exception(service, exception, host_data = nil)
      error_handler = Sanford::ErrorHandler.new(exception, host_data, service.request)
      service.response  = error_handler.run
      service.exception = error_handler.exception
      self.log_exception(service.exception)
      service
    end

    def raise_if_debugging!(exception)
      raise exception if exception && ENV['SANFORD_DEBUG']
    end

    def log_received
      self.logger.verbose.info("Received request")
    end

    def log_request(request)
      self.logger.verbose.info("  Version: #{request.version.inspect}")
      self.logger.verbose.info("  Service: #{request.name.inspect}")
      self.logger.verbose.info("  Params:  #{request.params.inspect}")
    end

    def log_handler_class(handler_class)
      self.logger.verbose.info("  Handler: #{handler_class}")
    end

    def log_complete(processed_service)
      self.logger.verbose.info "Completed in #{processed_service.time_taken}ms " \
        "#{processed_service.response.status}\n"
      self.logger.summary.info self.summary_line(processed_service).to_s
    end

    def log_exception(exception)
      self.logger.verbose.error("#{exception.class}: #{exception.message}")
      self.logger.verbose.error(exception.backtrace.join("\n"))
    end

    def summary_line(processed_service)
      SummaryLine.new.tap do |line|
        if (request = processed_service.request)
          line.add 'version', request.version
          line.add 'service', request.name
          line.add 'params',  request.params
        end
        line.add 'handler',   processed_service.handler_class
        line.add 'status',    processed_service.response.code if processed_service.response
        line.add 'duration',  processed_service.time_taken
      end
    end

    ROUND_PRECISION = 2
    ROUND_MODIFIER = 10 ** ROUND_PRECISION
    def round_time(time_in_seconds)
      (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
    end

    class SummaryLine

      def initialize
        @hash = {}
      end

      def add(key, value)
        @hash[key] = value.inspect if value
      end

      def to_s
        [ 'version', 'service', 'handler', 'status', 'duration', 'params' ].map do |key|
          "#{key}=#{@hash[key]}" if @hash[key]
        end.compact.join(" ")
      end

    end

  end

end
