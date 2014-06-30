require 'sanford-protocol'

class FakeServerConnection

  attr_reader :request, :response
  attr_reader :write_closed
  attr_accessor :raise_on_write, :write_exception
  attr_writer :read_data

  def self.with_request(name, params = nil)
    self.new.tap{ |c| c.add_request(name, params) }
  end

  def initialize(read_data = nil)
    @read_data = read_data
    @raise_on_write = false
    @write_closed = false

    @write_exception = RuntimeError.new('oops')

    @request = nil
    @response = nil
  end

  def add_request(name, params = nil)
    @request = Sanford::Protocol::Request.new(name, params || {})
    @read_data = @request.to_hash
  end

  def read_data
    @read_data || {}
  end

  def write_data(data = nil)
    write_data!(data) if data
    @write_data
  end

  def peek_data
    @read_data ? @read_data[0] : ""
  end

  def close_write
    @write_closed = true
  end

  private

  def write_data!(data)
    if @raise_on_write
      @raise_on_write = false
      raise @write_exception
    end
    @response = Sanford::Protocol::Response.parse(data) rescue nil
    @write_data = data
  end

end
