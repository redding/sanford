module Sanford

  class ServerData

    # The server uses this to "compile" its configuration for speed. NsOptions
    # is relatively slow everytime an option is read. To avoid this, we read the
    # options one time here and memoize their values. This way, we don't pay the
    # NsOptions overhead when reading them while handling a request.

    attr_reader :name
    attr_reader :pid_file
    attr_reader :receives_keep_alive
    attr_reader :verbose_logging, :logger, :template_source
    attr_reader :init_procs, :error_procs
    attr_reader :worker_start_procs, :worker_shutdown_procs
    attr_reader :worker_sleep_procs, :worker_wakeup_procs
    attr_reader :router, :routes
    attr_accessor :ip, :port

    def initialize(args = nil)
      args ||= {}
      @name     = args[:name]
      @ip       = args[:ip]
      @port     = args[:port]
      @pid_file = args[:pid_file]

      @receives_keep_alive = !!args[:receives_keep_alive]

      @verbose_logging = !!args[:verbose_logging]
      @logger          = args[:logger]
      @template_source = args[:template_source]

      @init_procs  = args[:init_procs]  || []
      @error_procs = args[:error_procs] || []

      @worker_start_procs    = args[:worker_start_procs]
      @worker_shutdown_procs = args[:worker_shutdown_procs]
      @worker_sleep_procs    = args[:worker_sleep_procs]
      @worker_wakeup_procs   = args[:worker_wakeup_procs]

      @router = args[:router]
      @routes = build_routes(args[:routes] || [])
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
