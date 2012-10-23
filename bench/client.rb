require 'socket'

require 'sanford'

module Bench

  class Client

    def initialize(host, port)
      addr = Socket.pack_sockaddr_in(port, host)
      @host, @port = [ host, port ]
    end

    def call(path, params)
      socket = TCPSocket.open(@host, @port)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true) # TODO - explain
      request = Sanford::Request.new(path, [ params ])
      socket.send(request.serialize, 0)
      if IO.select([ socket ], nil, nil, 10)
        serialized_size = socket.recvfrom(Sanford::Message.number_size_bytes).first
        response_size = Sanford::Response.deserialize_size(serialized_size)
        serialized_version = socket.recvfrom(Sanford::Message.number_version_bytes).first
        if response_size
          serialized_response = socket.recvfrom(response_size).first
          Sanford::Response.parse(serialized_response)
        else
          raise "No response size!"
        end
      else
        raise "Timed out!"
      end
    ensure
      socket.close rescue false
    end

  end

end
