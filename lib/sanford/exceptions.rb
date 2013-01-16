module Sanford

  class BaseError < RuntimeError; end

  class NotFoundError < BaseError; end

  class NoHostError < BaseError
    attr_reader :message

    def initialize(host_name)
      @message = if Sanford.hosts.empty?
        "No hosts have been defined. " \
        "Please define a host before trying to run Sanford."
      else
        "A host couldn't be found with the name #{host_name.inspect}. "
      end
    end
  end

  class InvalidHostError < BaseError
    attr_reader :message

    def initialize(host)
      @message = "A port must be configured or provided to build an instance of '#{host}'"
    end
  end

  class NoHandlerClassError < BaseError
    attr_reader :message

    def initialize(host, handler_class_name)
      @message = "Sanford couldn't find the service handler '#{handler_class_name}'." \
        "It doesn't exist or hasn't been required in yet."
    end
  end

end
