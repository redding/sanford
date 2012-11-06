# Sanford's connection handler is responsible for processing a connection to
# Sanford's server. It takes a service host and client socket and is responsible
# for parsing the request from the client socket. If any part of this fails, it
# builds a response based on the exception thrown and returns that. If a request
# is successfully parsed, it is handed off to the service host.
#
# Notes:
# * This class is separated from `Sanford::Server` to help with thread safety.
#   The server creates a new instance of this class per connection, which means
#   there is a separate connection handler per thread.
#
require 'benchmark'

require 'sanford/exceptions'
require 'sanford/request'
require 'sanford/response'

module Sanford

  class ConnectionHandler
    attr_reader :client_socket, :service_host, :logger, :request, :response,
      :serialized_response

    def initialize(service_host, client_socket)
      @service_host = service_host
      @client_socket = client_socket
      @logger = self.service_host.logger

      self.process_connection
      @serialized_response = @response.serialize
    end

    protected

    def process_connection
      self.logger.info("Received request")
      benchmark = Benchmark.measure do
        begin
          @request = self.parse_request
          self.logger.info("  Service: #{@request.service_name.inspect}")
          self.logger.info("  Version: #{@request.service_version.inspect}")
          self.logger.info("  Parameters: #{@request.params.inspect}")
          status, result = self.service_host.route(self.request)
          @response = self.build_response(status, result)
        rescue Exception => exception
          handler = self.service_host.exception_handler.new(exception, self.logger)
          @response = handler.response
        end
      end
      time_taken = self.round_time(benchmark.real)
      self.logger.info("Completed in #{time_taken}ms #{self.response.status}\n")
    end

    def parse_request
      size = self.parse_request_size
      self.parse_request_protocol_version
      request = self.parse_request_body(size)
      self.validate_request(request)
      request
    end

    def build_response(status, result)
      status ||= :success
      Sanford::Response.new(status, result)
    end

    def parse_request_size
      serialized_size = self.client_socket.read(Sanford::Request.number_size_bytes)
      Sanford::Request.deserialize_size(serialized_size)
    rescue Exception
      raise Sanford::BadRequestError, "The size couldn't be parsed."
    end

    def parse_request_protocol_version
      matches = true
      serialized_version = self.client_socket.read(Sanford::Request.number_version_bytes)
      matches = (serialized_version == Sanford::Request.serialized_protocol_version)
      raise if !matches
    rescue Exception
      message = if !matches
        "The protocol version didn't match the servers."
      else
        "The protocol version couldn't be parsed."
      end
      raise Sanford::BadRequestError, message
    end

    def parse_request_body(size)
      serialized_request = self.client_socket.read(size)
      Sanford::Request.parse(serialized_request)
    rescue Exception
      raise Sanford::BadRequestError, "The request body couldn't be parsed."
    end

    def validate_request(request)
      if request.service_name.nil?
        raise "The request doesn't contain a service name."
      elsif request.service_version.nil?
        raise "The request doesn't contain a service version."
      end
    rescue Exception => exception
      raise Sanford::BadRequestError, exception.message
    end

    def round_time(time_in_seconds)
      ((time_in_seconds * 1000.to_f) + 0.5).to_i
    end

  end

end
