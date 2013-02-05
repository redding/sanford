require 'dat-tcp'
require 'sanford-protocol'

require 'sanford/host_data'
require 'sanford/worker'

module Sanford

  class Server
    include DatTCP::Server

    def initialize(host, options = {})
      @service_host, @host_options = host, options
      ip    = options[:ip]   || host.ip
      port  = options[:port] || host.port
      super(ip, port, options)
    end

    def on_start
      @host_data = Sanford::HostData.new(@service_host, @host_options)
    end

    # `serve` can be called at the same time by multiple threads. Thus we create
    # a new instance of the handler for every request.
    def serve(socket)
      connection = Connection.new(socket)
      if !self.keep_alive_connection?(connection)
        Sanford::Worker.new(@host_data, connection).run
      end
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @service_host=#{@host_data.inspect}>"
    end

    protected

    def keep_alive_connection?(connection)
      @host_data.keep_alive && connection.peek_data.empty?
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
