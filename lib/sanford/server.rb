require 'dat-tcp'
require 'sanford-protocol'

require 'sanford/host_data'
require 'sanford/worker'

module Sanford

  class Server
    include DatTCP::Server
    attr_reader :sanford_host, :sanford_host_data, :sanford_host_options

    def initialize(host, options = {})
      @sanford_host = host
      # FUTURE read off overrides from options for verbose / keep_alive here
      @sanford_host_options = options[:sanford_host] || {}
      super options
    end

    def on_run
      @sanford_host_data = Sanford::HostData.new(@sanford_host, @sanford_host_options)
    end

    # `serve` can be called at the same time by multiple threads. Thus we create
    # a new instance of the handler for every request.
    def serve(socket)
      connection = Connection.new(socket)
      if !self.keep_alive_connection?(connection)
        Sanford::Worker.new(@sanford_host_data, connection).run
      end
    end

    protected

    def keep_alive_connection?(connection)
      @sanford_host_data.keep_alive && connection.peek_data.empty?
    end

    class Connection

      DEFAULT_TIMEOUT = 1

      def initialize(socket)
        @connection = Sanford::Protocol::Connection.new(socket)
        @timeout    = (ENV['SANFORD_TIMEOUT'] || DEFAULT_TIMEOUT).to_f
      end

      def read_data
        @connection.read(@timeout)
      end

      def write_data(data)
        @connection.write data
      end

      def peek_data
        @connection.peek(@timeout)
      end

    end

  end

end
