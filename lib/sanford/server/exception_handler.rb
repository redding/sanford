# Sanford's exception handler class takes an exception and builds a valid
# response. For certain exceptions, Sanford will use special response codes and
# for all others it will classify them as generic error requests.
#
class Sanford::Server

  class ExceptionHandler
    attr_reader :exception, :response

    def initialize(exception)
      @exception = exception
      status = Sanford::Response::Status.new(*self.determine_code_and_message)
      @response = Sanford::Response.new(status)
    end

    protected

    def determine_code_and_message
      case(self.exception)
      when Sanford::BadRequest
        [ :bad_request, self.exception.message ]
      when Sanford::NotFound
        [ :not_found ]
      when Exception
        [ :error, "An unexpected error occurred." ]
      end
    end

  end

end
