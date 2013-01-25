module Sanford

  BaseError = Class.new(RuntimeError)

  NotFoundError = Class.new(RuntimeError)

  class NoHostError < BaseError

    def initialize(host_name)
      message = if Sanford.hosts.empty?
        "No hosts have been defined. Please define a host before trying to run Sanford."
      else
        "A host couldn't be found with the name #{host_name.inspect}. "
      end
      super message
    end

  end

  class InvalidHostError < BaseError

    def initialize(host)
      super "A port must be configured or provided to run a server for '#{host}'"
    end

  end

  class NoHandlerClassError < BaseError

    def initialize(handler_class_name)
      super "Sanford couldn't find the service handler '#{handler_class_name}'. " \
        "It doesn't exist or hasn't been required in yet."
    end

  end

end
