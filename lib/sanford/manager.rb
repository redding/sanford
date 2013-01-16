require 'daemons'

require 'sanford/exceptions'
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

    attr_reader :service_host, :process_name, :options

    def initialize(service_host, overrides = {})
      @service_host = service_host
      @options = Options.new(service_host, overrides)
      raise Sanford::InvalidServerOptionsError.new(service_host) if !options.port
      @process_name = [ options.ip, options.port, options.name ].join('_')
    end

    def call(action)
      daemons_options = self.default_options.merge({ :ARGV => [ action.to_s ] })
      FileUtils.mkdir_p(daemons_options[:dir])
      ::Daemons.run_proc(self.process_name, daemons_options) do
        server = Sanford::Server.new(self.service_host, self.options.hash)
        server.start
        server.join_thread
      end
    end

    protected

    def default_options
      { :dir_mode   => :normal,
        :dir        => self.options.pid_dir
      }
    end

    class Options < OpenStruct
      attr_reader :hash

      # Remove `nil` values here to avoid accidentally overwriting the defaults
      # provided by the service host configuration. Because these values come
      # from the manager which uses ENV vars, they can be unintentionally `nil`.
      def initialize(service_host, overrides = nil)
        @hash = service_host.configuration.to_hash.merge(remove_nil_values(overrides || {}))
        super(@hash)
      end

      protected

      def remove_nil_values(hash)
        hash.inject({}){|h, (k, v)| !v.nil? ? h.merge({ k => v }) : h }
      end

    end

  end

end
