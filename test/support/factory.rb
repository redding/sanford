require 'assert/factory'

module Factory
  extend Assert::Factory

  def self.exception(klass = nil, message = nil)
    klass ||= StandardError
    message ||= Factory.text
    exception = nil
    begin; raise(klass, message); rescue klass => exception; end
    exception.set_backtrace(nil) if Factory.boolean
    exception
  end

  def self.protocol_response
    Sanford::Protocol::Response.new(
      [Factory.integer(999), Factory.text],
      { Factory.string => Factory.string }
    )
  end

end
