require 'benchmark'
require 'sanford-protocol'

require 'sanford/logger'

module Sanford

  class Worker

    attr_reader :logger

    def initialize(service_host)
      @service_host = service_host

      @logger = Sanford::Logger.new(@service_host.logger, @service_host.verbose_logging)
      @exception_handler = @service_host.exception_handler
    end

    def run(connection)
      self.log_received
      benchmark = Benchmark.measure do
        self.run!(connection)
      end
      @time_taken = self.round_time(benchmark.real)
      self.log_complete
      self.raise_if_debugging!
    end

    protected

    def run!(connection)
      @request = Sanford::Protocol::Request.parse(connection.read_data)
      self.log_request
      @handler_class = @service_host.handler_class_for(@request.version, @request.name)
      self.log_handler_class
      # @response = Sanford::Runner.new(@handler_class, @request).response
      response_args = @handler_class.new(@service_host.logger, @request).run
      @response = Sanford::Protocol::Response.new(*response_args)
    rescue Exception => @exception
      @response = @exception_handler.new(@exception, @logger).response
    ensure
      connection.write_data(@response.to_hash)
    end

    def raise_if_debugging!
      raise @exception if @exception && ENV['SANFORD_DEBUG']
    end

    def log_received
      self.logger.verbose.info("Received request")
    end

    def log_request
      self.logger.verbose.info("  Version: #{@request.version.inspect}")
      self.logger.verbose.info("  Service: #{@request.name.inspect}")
    end

    def log_handler_class
      self.logger.verbose.info("  Handler: #{@handler_class}")
      self.logger.verbose.info("  Params:  #{@request.params.inspect}")
    end

    def log_complete
      self.logger.verbose.info("Completed in #{@time_taken}ms #{@response.status}\n")
      self.logger.summary.info self.summary_line.to_s
    end

    def summary_line
      SummaryLine.new.tap do |line|
        if @request
          line.add 'version', @request.version
          line.add 'service', @request.name
          line.add 'params',  @request.params
        end
        line.add 'handler',   @handler_class
        line.add 'status',    @response.status.code if @response
        line.add 'duration',  @time_taken
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

      # change the key's order in the array to change the order to change the
      # order they appear in when logged
      def to_s
        [ 'version', 'service', 'handler', 'status', 'duration', 'params' ].map do |key|
          "#{key}=#{@hash[key]}" if @hash[key]
        end.compact.join(" ")
      end

    end

  end

end
