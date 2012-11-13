# Sanford's server uses DatTCP for a TCP Server. When a client connects, the
# `serve` method is called. Sanford creates a new instance of a connection
# handler and hands it the service host and client socket. This is because the
# `serve` method can be accessed by multiple threads, so we essentially create a
# new connection handler per thread.
#
require 'dat-tcp'

require 'sanford/connection'

module Sanford

  class Server
    include DatTCP::Server

    attr_reader :service_host

    def initialize(service_host, options = {})
      @service_host = service_host
      super(self.service_host.hostname, self.service_host.port, options)
    end

    def name
      self.service_host.name
    end

    def serve(wrapped_socket)
      connection = Sanford::Connection.new(self.service_host, wrapped_socket.socket)
      connection.process
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @service_host=#{self.service_host.inspect}>"
    end

  end

end
