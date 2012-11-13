# Sanford's exception handler class takes an exception and builds a valid
# response. For certain exceptions, Sanford will use special response codes and
# for all others it will classify them as generic error requests.
#
require 'sanford-protocol'

require 'sanford/exceptions'

module Sanford

  class ExceptionHandler
    attr_reader :exception, :logger

    def initialize(exception, logger)
      @exception = exception
      @logger = logger
    end

    def response
      self.logger.error("#{exception.class}: #{exception.message}")
      self.logger.error(exception.backtrace.join("\n"))
      status = Sanford::Protocol::ResponseStatus.new(*self.determine_code_and_message)
      Sanford::Protocol::Response.new(status)
    end

    protected

    def determine_code_and_message
      case(self.exception)
      when Sanford::Protocol::BadMessageError
        [ :bad_request, self.exception.message ]
      when Sanford::NotFoundError
        [ :not_found ]
      when Exception
        [ :error, "An unexpected error occurred." ]
      end
    end

  end

end
