require 'daemons'

require 'sanford/host_data'
require 'sanford/server'

module Sanford

  class Manager

    def self.call(action, options = nil)
      options ||= {}
      options[:ip]    ||= ENV['SANFORD_IP']
      options[:port]  ||= ENV['SANFORD_PORT']

      name = options.delete(:host) || ENV['SANFORD_HOST']
      service_host = name ? Sanford.hosts.find(name) : Sanford.hosts.first
      raise(Sanford::NoHostError.new(name)) if !service_host

      self.new(service_host, options).call(action)
    end

    attr_reader :process_name

    def initialize(service_host, options = {})
      @service_host, @host_options = service_host, options
      @pid_dir      = @service_host.pid_dir || @host_options[:pid_dir]
      @process_name = ProcessName.new(@service_host, @host_options)
    end

    def call(action)
      daemons_options = self.default_options.merge({ :ARGV => [ action.to_s ] })
      FileUtils.mkdir_p(daemons_options[:dir])
      ::Daemons.run_proc(self.process_name, daemons_options) do
        server = Sanford::Server.new(@service_host, @host_options)
        server.connect

        Signal.trap("TERM"){ server.stop }

        server.start
        server.join_thread
      end
    end

    protected

    def default_options
      { :dir_mode   => :normal,
        :dir        => @pid_dir
      }
    end

    class ProcessName < String
      attr_reader :ip, :port

      def initialize(host, options)
        @ip    = options[:ip] || host.ip
        @port  = options[:port] || host.port
        super [ @ip, @port, host.name ].join('_')
      end

    end

  end

end
