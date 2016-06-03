module Sanford

  class ServerData

    # The server uses this to "compile" the common configuration data used
    # by the server instances, error handlers and routes. The goal here is
    # to provide these with a simplified interface with the minimal data needed
    # and to decouple the configuration from each thing that needs its data.

    attr_accessor :ip, :port
    attr_reader :name, :pid_file, :shutdown_timeout
    attr_reader :worker_class, :worker_params, :num_workers
    attr_reader :error_procs, :template_source, :logger, :router
    attr_reader :receives_keep_alive, :verbose_logging
    attr_reader :debug, :dtcp_logger, :routes

    def initialize(args = nil)
      args ||= {}
      @name     = args[:name]
      @ip       = !(v = ENV['SANFORD_IP'].to_s).empty?   ? v      : args[:ip]
      @port     = !(v = ENV['SANFORD_PORT'].to_s).empty? ? v.to_i : args[:port]
      @pid_file = args[:pid_file]

      @shutdown_timeout = args[:shutdown_timeout]

      @worker_class    = args[:worker_class]
      @worker_params   = args[:worker_params] || {}
      @num_workers     = args[:num_workers]
      @error_procs     = args[:error_procs] || []
      @template_source = args[:template_source]
      @logger          = args[:logger]
      @router          = args[:router]

      @receives_keep_alive = !!args[:receives_keep_alive]
      @verbose_logging     = !!args[:verbose_logging]

      @debug       = !ENV['SANFORD_DEBUG'].to_s.empty?
      @dtcp_logger = @logger if @debug
      @routes      = build_routes(args[:routes] || [])
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
