# TODO - this is not in a done state by any stretch is just a quick implementation
# to get something working.
require 'bson'
require 'threaded_server'

module Sanford

  class Server < ThreadedServer
    attr_reader :service_host

    def initialize(service_host)
      @service_host = service_host
      # TODO - raise exception if no host/port
      service_host.config.tap do |config|
        super(config.host, config.port, {
          :logging  => !!config.logging,
          :logger   => config.logger
        })
      end
    end

    def name
      self.service_host.to_s
    end

    def serve(client_socket)
      # TODO - this will change as I modify the protocol
      serialized_size = client_socket.read(4)
      size = serialized_size.unpack('N').first
      serialized_request = client_socket.read(size)
      request = BSON.deserialize(serialized_request)
      # TODO - this will change when we configure services
      path, data = [*request].first
      response_data = case(path)
        when 'v1/simple'
          { :string => 'test', :int => 1, :float => 2.1, :boolean => true,
            :hash => { :something => 'else' }, :array => [ 1, 2, 3 ],
            :request_number => data['request_number']
          }
      end
      response = { :body => response_data }
      # TODO - this will change as I modify the protocol
      serialized_response = BSON.serialize(response)
      serialized_size = [ serialized_response.size ].pack('N')
      client_socket.write(serialized_size + serialized_response.to_s)
    end

  end

end
