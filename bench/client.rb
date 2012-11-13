require 'socket'

require 'sanford-protocol'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    def call(version, name, params)
      socket = TCPSocket.open(@host, @port)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true) # TODO - explain
      connection = Sanford::Protocol::Connection.new(socket)
      request = Sanford::Protocol::Request.new(version, name, params)
      connection.write(request.to_hash)
      if IO.select([ socket ], nil, nil, 10)
        Sanford::Protocol::Response.parse(connection.read)
      else
        raise "Timed out!"
      end
    ensure
      socket.close rescue false
    end

  end

end
