require 'ostruct'
require 'sanford-protocol'

module Sanford

  class ErrorHandler

    attr_reader :exception, :host_data, :request

    def initialize(exception, host_data = nil, request = nil)
      @exception, @host_data, @request = exception, host_data, request
      @keep_alive = @host_data ? @host_data.keep_alive : false
      @error_proc = @host_data ? @host_data.error_proc : proc{ }
    end

    # The exception that we are generating a response for can change in the case
    # that the configured error proc raises an exception. If this occurs, a
    # response will be generated for that exception, instead of the original
    # one. This is designed to avoid "hidden" errors happening, this way the
    # server will respond and log based on the last exception that occurred.

    def run
      begin
        result = @error_proc.call(@exception, @host_data, @request)
      rescue Exception => proc_exception
        @exception = proc_exception
      end
      self.response_from_proc(result) || self.response_from_exception(@exception)
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
      when Sanford::Protocol::EndOfStreamError
        if @keep_alive
          build_response :ok
        else
          build_response :bad_request, :message => "Couldn't read request."
        end
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
