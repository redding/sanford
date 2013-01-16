require 'dat-tcp'
require 'ostruct'
require 'sanford-protocol'

require 'sanford/worker'

module Sanford

  class Server
    include DatTCP::Server

    def initialize(service_host, options = {})
      @service_host = service_host
      @configuration = OpenStruct.new(@service_host.configuration.to_hash.merge(options))
      super(@configuration.ip, @configuration.port, options)
    end

    def name
      @service_host.name
    end

    # `serve` can be called at the same time by multiple threads. Thus we create
    # a new instance of the handler for every request.
    def serve(socket)
      Sanford::Worker.new(@service_host).run(Connection.new(socket))
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @service_host=#{@service_host.inspect}>"
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
