require 'dat-tcp'
require 'sanford-protocol'

require 'sanford/host_data'
require 'sanford/worker'

module Sanford

  class Server
    include DatTCP::Server

    attr_reader :host_data

    def initialize(host, options = {})
      @host_data = Sanford::HostData.new(host, options)
      super(@host_data.ip, @host_data.port, options)
    end

    def name
      @host_data.name
    end

    # `serve` can be called at the same time by multiple threads. Thus we create
    # a new instance of the handler for every request.
    def serve(socket)
      Sanford::Worker.new(@host_data, Connection.new(socket)).run
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @service_host=#{@host_data.inspect}>"
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

    end

  end

end
