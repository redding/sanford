require 'much-plugin'
require 'dat-tcp/worker'
require 'sanford/connection_handler'
require 'sanford/server_data'

module Sanford

  module Worker
    include MuchPlugin

    plugin_included do
      include DatTCP::Worker
      include InstanceMethods

    end

    module InstanceMethods

      def work!(client_socket)
        connection = Connection.new(client_socket)
        return if sanford_keep_alive_connection?(connection)
        Sanford::ConnectionHandler.new(params[:sanford_server_data], connection).run
      ensure
        connection.close rescue false
      end

      private

      def sanford_keep_alive_connection?(connection)
        params[:sanford_server_data].receives_keep_alive && connection.peek_data.empty?
      end

    end

    class Connection
      DEFAULT_TIMEOUT = 1

      attr_reader :timeout

      def initialize(socket)
        @socket     = socket
        @connection = Sanford::Protocol::Connection.new(@socket)
        @timeout    = (ENV['SANFORD_TIMEOUT'] || DEFAULT_TIMEOUT).to_f
      end

      def write_data(data)
        TCPCork.apply(@socket)
        @connection.write data
        TCPCork.remove(@socket)
      end

      def read_data;   @connection.read(@timeout); end
      def peek_data;   @connection.peek(@timeout); end
      def close;       @connection.close;          end
      def close_write; @connection.close_write;    end
    end

    module TCPCork
      # On Linux, use TCP_CORK to better control how the TCP stack
      # packetizes our stream. This improves both latency and throughput.
      # TCP_CORK disables Nagle's algorithm, which is ideal for sporadic
      # traffic (like Telnet) but is less optimal for HTTP. Sanford is similar
      # to HTTP, it doesn't receive sporadic packets, it has all its data
      # come in at once.
      # For more information: http://baus.net/on-tcp_cork

      if RUBY_PLATFORM =~ /linux/
        # 3 == TCP_CORK
        def self.apply(socket)
          socket.setsockopt(::Socket::IPPROTO_TCP, 3, true)
        end

        def self.remove(socket)
          socket.setsockopt(::Socket::IPPROTO_TCP, 3, false)
        end
      else
        def self.apply(socket);  end
        def self.remove(socket); end
      end
    end

    module TestHelpers
      include MuchPlugin

      plugin_included do
        include DatTCP::Worker::TestHelpers
        include InstanceMethods
      end

      module InstanceMethods

        def test_runner(worker_class, options = nil)
          options ||= {}
          options[:params] = {
            :sanford_server_data => Sanford::ServerData.new,
          }.merge(options[:params] || {})
          super(worker_class, options)
        end

      end

    end

  end

end
