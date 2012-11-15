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

    attr_reader :service_host, :logger, :exception_handler

    def initialize(service_host, client_socket)
      @service_host = service_host
      @exception_handler  = self.service_host.exception_handler
      @logger             = self.service_host.logger
      super(client_socket)
    end

    def process
      response = nil
      self.logger.info("Received request")
      benchmark = Benchmark.measure do
        begin
          request = Sanford::Protocol::Request.parse(self.read)
          self.validate!(request)
          self.log_request(request)
          status, result = self.route(request)
          response = Sanford::Protocol::Response.new(status, result)
        rescue Exception => exception
          handler = self.exception_handler.new(exception, self.logger)
          response = handler.response
        ensure
          self.write(response.to_hash)
        end
      end
      time_taken = self.round_time(benchmark.real)
      self.logger.info("Completed in #{time_taken}ms #{response.status}\n")
    end

    protected

    def route(request)
      self.service_host.route(request)
    end

    def log_request(request)
      self.logger.info("  Version: #{request.version.inspect}")
      self.logger.info("  Service: #{request.name.inspect}")
      self.logger.info("  Parameters: #{request.params.inspect}")
    end

    def validate!(request)
      valid, reason = request.valid?
      raise(Sanford::Protocol::BadMessageError, reason) if !valid
    end

    def round_time(time_in_seconds)
      ((time_in_seconds * 1000.to_f) + 0.5).to_i
    end

  end

end
