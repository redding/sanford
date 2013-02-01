require 'sanford/exceptions'
require 'sanford/service_handler'

module Sanford

  class HostData

    # When trying to run a server for a host, we need to build up the host's
    # data to increase the performance of the server. This is done by
    # constantizing a host's handlers and merging a host's configuration with
    # optional overrides.

    attr_reader :name, :ip, :port, :logger, :verbose, :keep_alive, :error_proc

    def initialize(service_host, options = nil)
      service_host.configuration.setup_proc.call

      overrides = self.remove_nil_values(options || {})
      configuration = service_host.configuration.to_hash.merge(overrides)

      @name       = configuration[:name]
      @ip         = configuration[:ip]
      @port       = configuration[:port]
      @logger     = configuration[:logger]
      @verbose    = configuration[:verbose_logging]
      @keep_alive = configuration[:receives_keep_alive]
      @error_proc = configuration[:error_proc]

      @handlers = service_host.versioned_services.inject({}) do |hash, (version, services)|
        hash.merge({ version => self.constantize_services(services) })
      end

      raise Sanford::InvalidHostError.new(@service_host) if !@port
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

end
