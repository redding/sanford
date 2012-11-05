# A Sanford response is a specific type of Sanford message. It defines the
# structure of a response: status and result. Result is optional, but should be
# included in many cases. The parse method defines how to take a serialized
# response string and build a Sanford response object from it.
#
require 'sanford/message'

module Sanford

  class Response < Sanford::Message

    class Status < Struct.new(:code, :message)

      CODES = {
        :success      => 200,
        :bad_request  => 400,
        :not_found    => 404,
        :error        => 500
      }.freeze

      def initialize(code, message = nil)
        number = CODES[code.to_sym] || code.to_i
        super(number, message)
      end

      def name
        key = CODES.index(self.code)
        key.to_s.upcase if key
      end

      def to_s
        "[#{[ self.code, self.name ].compact.join(', ')}]"
      end

      def inspect
        msg = self.message if self.message && !self.message.empty?
        [ self.code, self.name, msg ].compact.inspect
      end

    end

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

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @status=#{self.status.inspect} @result=#{self.result.inspect}>"
    end

    protected

    def build_status(status)
      if status.kind_of?(Array)
        Sanford::Response::Status.new(*status)
      elsif status.kind_of?(Sanford::Response::Status)
        status
      else
        Sanford::Response::Status.new(status)
      end
    end

  end

end
