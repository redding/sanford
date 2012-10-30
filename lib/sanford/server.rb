# Sanford's server uses DatTCP for a TCP Server. When a client connects, the
# `serve` method is called. Sanford creates a new instance of a connection
# handler and hands it the service host and client socket. This is because the
# `serve` method can be accessed by multiple threads, so we essentially create a
# new connection handler per thread.
#
require 'dat-tcp'

require 'sanford/server/connection_handler'

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

    def serve(client_socket)
      handler = Sanford::Server::ConnectionHandler.new(self.service_host, client_socket)
      client_socket.write(handler.serialized_response)
    end

  end

end
