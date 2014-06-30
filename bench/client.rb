require 'socket'

require 'sanford-protocol'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    # TCP_NODELAY is set to disable buffering. In the case of Sanford
    # communication, we have all the information we need to send up front and
    # are closing the connection, so it doesn't need to buffer.
    # See http://linux.die.net/man/7/tcp

    def call(name, params)
      socket = TCPSocket.open(@host, @port)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true)
      connection = Sanford::Protocol::Connection.new(socket)
      request = Sanford::Protocol::Request.new(name, params)
      connection.write(request.to_hash)
      connection.close_write
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
