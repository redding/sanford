require 'dat-worker-pool/worker'
require 'sanford-protocol'

module Sanford

  class ErrorHandler

    # these are standard error classes that we rescue and run through any
    # configured error procs; use the same standard error classes that
    # dat-worker-pool rescues
    STANDARD_ERROR_CLASSES = DatWorkerPool::Worker::STANDARD_ERROR_CLASSES

    attr_reader :exception, :context, :error_procs

    def initialize(exception, context_hash)
      @exception   = exception
      @context     = ErrorContext.new(context_hash)
      @error_procs = context_hash[:server_data].error_procs.reverse
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
          result = error_proc.call(@exception, @context)
        rescue *STANDARD_ERROR_CLASSES => proc_exception
          @exception = proc_exception
        end
        response ||= response_from_proc(result)
      end
      response || response_from_exception(@exception)
    end

    private

    def response_from_proc(result)
      if result.kind_of?(Sanford::Protocol::Response)
        result
      elsif result.kind_of?(Integer) || result.kind_of?(Symbol)
        build_response result
      end
    end

    def response_from_exception(exception)
      if exception.kind_of?(Sanford::Protocol::BadMessageError) ||
         exception.kind_of?(Sanford::Protocol::Request::InvalidError)
        build_response 400, :message => exception.message # BAD REQUEST
      elsif exception.kind_of?(Sanford::NotFoundError)
        build_response 404 # NOT FOUND
      elsif exception.kind_of?(Sanford::Protocol::TimeoutError)
        build_response 408 # TIMEOUT
      else
        build_response 500, :message => "An unexpected error occurred." # ERROR
      end
    end

    def build_response(status, options = nil)
      options ||= {}
      Sanford::Protocol::Response.new(
        [status, options[:message]],
        options[:data]
      )
    end

  end

  class ErrorContext
    attr_reader :server_data
    attr_reader :request, :handler_class, :response

    def initialize(args)
      @server_data   = args[:server_data]
      @request       = args[:request]
      @handler_class = args[:handler_class]
      @response      = args[:response]
    end

    def ==(other)
      if other.kind_of?(self.class)
        self.server_data   == other.server_data &&
        self.request       == other.request &&
        self.handler_class == other.handler_class &&
        self.response      == other.response
      else
        super
      end
    end
  end

end
