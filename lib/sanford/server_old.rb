require 'dat-tcp'
require 'ostruct'
require 'sanford-protocol'

require 'sanford/host_data'
require 'sanford/worker_old'

module Sanford

  class ServerOld

    attr_reader :sanford_host, :sanford_host_data, :sanford_host_options

    def initialize(host, options = nil)
      options ||= {}
      @sanford_host = host
      @sanford_host_options = {
        :receives_keep_alive => options.delete(:keep_alive),
        :verbose_logging     => options.delete(:verbose)
      }
      @dat_tcp_server = DatTCP::Server.new(options){ |socket| serve(socket) }
    end

    def ip
      @dat_tcp_server.ip
    end

    def port
      @dat_tcp_server.port
    end

    def listen(*args)
      @dat_tcp_server.listen(*args) do |tcp_server|
        configure_tcp_server(tcp_server)
      end
    end

    def start(*args)
      self.on_run
      @dat_tcp_server.start(*args)
    end

    def stop(*args)
      @dat_tcp_server.stop(*args)
    end

    def halt(*args)
      @dat_tcp_server.halt(*args)
    end

    # TCP_NODELAY is set to disable buffering. In the case of Sanford
    # communication, we have all the information we need to send up front and
    # are closing the connection, so it doesn't need to buffer.
    # See http://linux.die.net/man/7/tcp

    def configure_tcp_server(tcp_server)
      tcp_server.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
    end

    def on_run
      @sanford_host_data ||= Sanford::HostData.new(@sanford_host, @sanford_host_options)
    end

    # `serve` can be called at the same time by multiple threads. Thus we
    # create a new instance of the handler for every request.
    # When using TCP_CORK, you "cork" the socket, handle it and then "uncork"
    # it, see the `TCPCork` module for more info.

    def serve(socket)
      connection = Connection.new(socket)
      if !self.keep_alive_connection?(connection)
        Sanford::WorkerOld.new(@sanford_host_data, connection).run
      end
    end

    protected

    def keep_alive_connection?(connection)
      @sanford_host_data.receives_keep_alive && connection.peek_data.empty?
    end

    class Connection

      DEFAULT_TIMEOUT = 1

      def initialize(socket)
        @socket     = socket
        @connection = Sanford::Protocol::Connection.new(@socket)
        @timeout    = (ENV['SANFORD_TIMEOUT'] || DEFAULT_TIMEOUT).to_f
      end

      def read_data
        @connection.read(@timeout)
      end

      def write_data(data)
        TCPCork.apply(@socket)
        @connection.write data
        TCPCork.remove(@socket)
      end

      def peek_data
        @connection.peek(@timeout)
      end

      def close_write
        @connection.close_write
      end

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
          socket.setsockopt(Socket::IPPROTO_TCP, 3, true)
        end

        def self.remove(socket)
          socket.setsockopt(Socket::IPPROTO_TCP, 3, false)
        end
      else
        def self.apply(socket)
        end

        def self.remove(socket)
        end
      end

    end

  end

end
