require 'ostruct'
require 'sanford-protocol'

module Sanford

  class ErrorHandler

    attr_reader :exception, :config_data, :request
    attr_reader :error_procs

    def initialize(exception, config_data = nil, request = nil)
      @exception, @config_data, @request = exception, config_data, request
      @error_procs = @config_data ? @config_data.error_procs.reverse : []
    end

    # The exception that we are generating a response for can change in the case
    # that the configured error proc raises an exception. If this occurs, a
    # response will be generated for that exception, instead of the original
    # one. This is designed to avoid "hidden" errors happening, this way the
    # server will respond and log based on the last exception that occurred.

    def run
      response = nil
      @error_procs.each do |error_proc|
        result = nil
        begin
          result = error_proc.call(@exception, @config_data, @request)
        rescue StandardError => proc_exception
          @exception = proc_exception
        end
        response ||= self.response_from_proc(result)
      end
      response || self.response_from_exception(@exception)
    end

    protected

    def response_from_proc(result)
      case result
      when Sanford::Protocol::Response
        result
      when Integer, Symbol
        build_response result
      end
    end

    def response_from_exception(exception)
      case(exception)
      when Sanford::Protocol::BadMessageError, Sanford::Protocol::BadRequestError
        build_response :bad_request, :message => exception.message
      when Sanford::NotFoundError
        build_response :not_found
      when Sanford::Protocol::TimeoutError
        build_response :timeout
      when Exception
        build_response :error, :message => "An unexpected error occurred."
      end
    end

    def build_response(status, options = nil)
      options = OpenStruct.new(options || {})
      Sanford::Protocol::Response.new([ status, options.message ], options.data)
    end

  end

end
