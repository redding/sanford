require 'socket'

require 'sanford/io'
require 'sanford/request'
require 'sanford/response'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    def call(name, version, params)
      socket = TCPSocket.open(@host, @port)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true) # TODO - explain
      io = Sanford::IO.new(socket)
      request = Sanford::Request.new(name, version, params)
      io.write(request.to_message)
      if IO.select([ socket ], nil, nil, 10)
        message = io.read
        Sanford::Response.parse(message)
      else
        raise "Timed out!"
      end
    ensure
      socket.close rescue false
    end

  end

end
