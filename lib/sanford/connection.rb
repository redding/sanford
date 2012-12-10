# Sanford's connection class is an extesion of the connection class provided by
# Sanford-Protocol. It provides the main process of reading a request, routing
# it and writing a response. All requests are benchmarked and logged. The
# connection's `process` method should always try to return a response, so that
# clients do not have to timeout.
#
# Notes:
# * This class is separated from `Sanford::Server` to help with thread safety.
#   The server creates a new instance of this class per connection, which means
#   there is a separate connection per thread.
#
require 'benchmark'
require 'sanford-protocol'

require 'sanford/exceptions'

module Sanford

  class Connection < Sanford::Protocol::Connection

    DEFAULT_TIMEOUT = 1

    attr_reader :service_host, :logger, :exception_handler, :timeout

    def initialize(service_host, client_socket)
      @service_host = service_host
      @exception_handler  = self.service_host.exception_handler
      @logger             = self.service_host.logger
      @timeout            = (ENV['SANFORD_TIMEOUT'] || DEFAULT_TIMEOUT).to_f
      super(client_socket)
    end

    def process
      request, response = nil, nil
      self.logger.verbose.info("Received request")
      benchmark = Benchmark.measure do
        begin
          request = Sanford::Protocol::Request.parse(self.read(self.timeout))
          self.log_request(request)
          response = Sanford::Protocol::Response.new(*self.run(request))
        rescue Exception => exception
          handler = self.exception_handler.new(exception, self.logger)
          response = handler.response
        ensure
          self.write(response.to_hash)
        end
      end
      time_taken = self.round_time(benchmark.real)
      self.logger.verbose.info("Completed in #{time_taken}ms #{response.status}\n")
      self.log_summary(request, response, time_taken)
    end

    protected

    def run(request)
      self.service_host.run(request)
    end

    def log_request(request)
      self.logger.verbose.info("  Version: #{request.version.inspect}")
      self.logger.verbose.info("  Service: #{request.name.inspect}")
      self.logger.verbose.info("  Params:  #{request.params.inspect}")
    end

    def log_summary(request, response, time_taken)
      key_values = []
      if request
        key_values.push "version=#{request.version}"
        key_values.push "name=#{request.name}"
      end
      key_values.push("status=#{response.status.code}") if response
      key_values.push("duration=#{time_taken}")
      key_values.push "params=#{request.params.inspect}" if request
      self.logger.summary.info(key_values.join(" "))
    end

    ROUND_PRECISION = 2
    ROUND_MODIFIER = 10 ** ROUND_PRECISION
    def round_time(time_in_seconds)
      (time_in_seconds * 1000 * ROUND_MODIFIER).to_i / ROUND_MODIFIER.to_f
    end

  end

end
