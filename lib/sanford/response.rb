# A Sanford response is a specific type of Sanford message. It defines the
# structure of a response: status and result. Result is optional, but should be
# included in many cases. The parse method defines how to take a serialized
# response string and build a Sanford response object from it.
#
require 'sanford/message'

module Sanford

  class Response < Sanford::Message

    # Status Codes
    SUCCESS       = 200
    BAD_REQUEST   = 400
    UNAUTHORIZED  = 401
    NOT_FOUND     = 404
    ERROR         = 500

    Status = Struct.new(:code, :message)

    def self.parse(serialized_body)
      body = super(serialized_body)
      self.new(body['status'], body['result'])
    end

    attr_reader :status, :result

    def initialize(status, result = nil)
      @status, @result = [ self.build_status(status), result ]
      super({
        'status'  => [ self.status.code, self.status.message ],
        'result'  => self.result
      })
    end

    protected

    def build_status(status)
      if status.kind_of?(Array)
        Sanford::Response::Status.new(*status)
      elsif status.kind_of?(Sanford::Response::Status)
        status
      else
        Sanford::Response::Status.new(status.to_i, "")
      end
    end

  end

end
