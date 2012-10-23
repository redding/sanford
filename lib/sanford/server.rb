# TODO - this is not in a done state by any stretch is just a quick implementation
# to get something working.
require 'threaded_server'

require 'sanford/request'
require 'sanford/response'

module Sanford


  class Server < ThreadedServer
    attr_reader :service_host

    def initialize(service_host)
      @service_host = service_host
      super(self.service_host.hostname, self.service_host.port, {
        :logging => !!self.service_host.logging,
        :logger  => self.service_host.logger
      })
    end

    def name
      self.service_host.name
    end

    def serve(client_socket)
      serialized_size = client_socket.read(Sanford::Message.number_size_bytes)
      request_size = Sanford::Request.deserialize_size(serialized_size)
      serialized_version = client_socket.read(Sanford::Message.number_version_bytes)
      serialized_request = client_socket.read(request_size)
      request = Sanford::Request.parse(serialized_request)
      # TODO - this will change when we configure services
      params = request.params.first
      data = case(request.service_name)
        when 'v1/simple'
          { :string => 'test', :int => 1, :float => 2.1, :boolean => true,
            :hash => { :something => 'else' }, :array => [ 1, 2, 3 ],
            :request_number => params['request_number']
          }
      end
      status = Sanford::Response::Status.new(Sanford::Response::SUCCESS)
      # end TODO
      response = Sanford::Response.new(status, data)
      client_socket.write(response.serialize)
    end

  end

end
