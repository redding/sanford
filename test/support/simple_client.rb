require 'sanford-protocol/test/fake_socket'

class SimpleClient

  def self.call_with_request(service_host, version, name, params)
    self.new(service_host).call_with_request(version, name, params)
  end

  def self.call_with_msg_body(service_host, *args)
    self.new(service_host).call_with_msg_body(*args)
  end

  def self.call_with_encoded_msg_body(service_host, *args)
    self.new(service_host).call_with_encoded_msg_body(*args)
  end

  def self.call_with(service_host, bytes)
    self.new(service_host).call(bytes)
  end

  def initialize(service_host, options = {})
    @host, @port = service_host.ip, service_host.port
    @delay = options[:with_delay]
  end

  def call_with_request(*args)
    self.call_using_fake_socket(:with_request, *args)
  end

  def call_with_msg_body(*args)
    self.call_using_fake_socket(:with_msg_body, *args)
  end

  def call_with_encoded_msg_body(*args)
    self.call_using_fake_socket(:with_encoded_msg_body, *args)
  end

  def call(bytes)
    socket = TCPSocket.new(@host, @port)
    socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
    connection = Sanford::Protocol::Connection.new(socket)
    sleep(@delay) if @delay
    socket.send(bytes, 0)
    Sanford::Protocol::Response.parse(connection.read)
  ensure
    socket.close rescue false
  end

  protected

  def call_using_fake_socket(method, *args)
    self.call(Sanford::Protocol::Test::FakeSocket.send(method, *args).in)
  end

end
