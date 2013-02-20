require 'sanford/service_handler'

module Sanford

  class HostData

    # When trying to run a server for a host, we need to build up the host's
    # data to increase the performance of the server. This is done by
    # constantizing a host's handlers and merging a host's configuration with
    # optional overrides.

    # NOTE: The `name` attribute shouldn't be removed, it is used to identify
    # a `HostData`, particularly in error handlers
    attr_reader :name, :logger, :verbose, :keep_alive, :error_proc

    def initialize(service_host, options = nil)
      service_host.configuration.init_proc.call

      overrides = self.remove_nil_values(options || {})
      configuration = service_host.configuration.to_hash.merge(overrides)

      @name       = configuration[:name]
      @logger     = configuration[:logger]
      @verbose    = configuration[:verbose_logging]
      @keep_alive = configuration[:receives_keep_alive]
      @error_proc = configuration[:error_proc]

      @handlers = service_host.versioned_services.inject({}) do |hash, (version, services)|
        hash.merge({ version => self.constantize_services(services) })
      end
    end

    def handler_class_for(version, service)
      version_group = @handlers[version] || {}
      version_group[service] || raise(Sanford::NotFoundError)
    end

    protected

    def constantize_services(services)
      services.inject({}) do |hash, (name, handler_class_name)|
        hash.merge({ name => self.constantize(handler_class_name) })
      end
    end

    def constantize(handler_class_name)
      Sanford::ServiceHandler.constantize(handler_class_name) ||
        raise(Sanford::NoHandlerClassError.new(handler_class_name))
    end

    def remove_nil_values(hash)
      hash.inject({}){|h, (k, v)| !v.nil? ? h.merge({ k => v }) : h }
    end

  end

  NotFoundError = Class.new(RuntimeError)

  class NoHandlerClassError < RuntimeError
    def initialize(handler_class_name)
      super "Sanford couldn't find the service handler '#{handler_class_name}'. " \
        "It doesn't exist or hasn't been required in yet."
    end
  end

end
