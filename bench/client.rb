require 'bson'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    def call(path, params)
      socket = TCPSocket.open(@host, @port)
      # TODO - this will change as I work on the protocol stuff
      serialized_request = BSON.serialize({ path => params })
      serialized_size = [ serialized_request.size ].pack('N')
      socket.send(serialized_size + serialized_request.to_s, 0)
      if IO.select([ socket ], nil, nil, 10)
        serialized_size = socket.recvfrom(4).first
        response_size = serialized_size.unpack('N').first
        if response_size
          serialized_response = socket.recvfrom(response_size).first
          BSON.deserialize(serialized_response)
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
