module Sanford

  class ServerData

    # The server uses this to "compile" its configuration for speed. NsOptions
    # is relatively slow everytime an option is read. To avoid this, we read the
    # options one time here and memoize their values. This way, we don't pay the
    # NsOptions overhead when reading them while handling a request.

    attr_reader :name
    attr_reader :pid_file
    attr_reader :receives_keep_alive
    attr_reader :worker_class, :worker_params, :num_workers
    attr_reader :debug, :logger, :dtcp_logger, :verbose_logging
    attr_reader :template_source, :shutdown_timeout
    attr_reader :init_procs, :error_procs
    attr_reader :router, :routes
    attr_accessor :ip, :port

    def initialize(args = nil)
      args ||= {}
      @name     = args[:name]
      @ip       = !(v = ENV['SANFORD_IP'].to_s).empty?   ? v      : args[:ip]
      @port     = !(v = ENV['SANFORD_PORT'].to_s).empty? ? v.to_i : args[:port]
      @pid_file = args[:pid_file]

      @receives_keep_alive = !!args[:receives_keep_alive]

      @worker_class  = args[:worker_class]
      @worker_params = args[:worker_params] || {}
      @num_workers   = args[:num_workers]

      @debug           = !ENV['SANFORD_DEBUG'].to_s.empty?
      @logger          = args[:logger]
      @dtcp_logger     = @logger if @debug
      @verbose_logging = !!args[:verbose_logging]

      @template_source = args[:template_source]

      @shutdown_timeout = args[:shutdown_timeout]

      @init_procs  = args[:init_procs]  || []
      @error_procs = args[:error_procs] || []

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
