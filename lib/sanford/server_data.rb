module Sanford

  class ServerData

    # The server uses this to "compile" its configuration for speed. NsOptions
    # is relatively slow everytime an option is read. To avoid this, we read the
    # options one time here and memoize their values. This way, we don't pay the
    # NsOptions overhead when reading them while handling a request.

    attr_reader :name
    attr_reader :ip, :port
    attr_reader :pid_file
    attr_reader :logger, :verbose_logging
    attr_reader :receives_keep_alive
    attr_reader :error_procs
    attr_reader :routes
    attr_reader :template_source

    def initialize(args = nil)
      args ||= {}
      @name = args[:name]
      @ip   = args[:ip]
      @port = args[:port]
      @pid_file = args[:pid_file]
      @logger = args[:logger]
      @verbose_logging = !!args[:verbose_logging]
      @receives_keep_alive = !!args[:receives_keep_alive]
      @error_procs = args[:error_procs] || []
      @routes = build_routes(args[:routes] || [])
      @template_source = args[:template_source]
    end

    def route_for(name)
      @routes[name] || raise(NotFoundError, "no service named '#{name}'")
    end

    private

    def build_routes(routes)
      routes.inject({}){ |h, route| h.merge(route.name => route) }
    end

  end

  NotFoundError = Class.new(RuntimeError)

end
