class FakeConnection

  attr_reader :read_data, :response
  attr_reader :write_stream_closed
  attr_accessor :raise_on_write, :write_exception

  def self.with_request(name, params = {}, raise_on_write = false)
    request = Sanford::Protocol::Request.new(name, params)
    self.new(request.to_hash, raise_on_write)
  end

  def initialize(*args)
    if args.first.kind_of?(Sanford::Protocol::Connection)
      protocol_connection = args.first
      @read_data = proc{ protocol_connection.read }
      @write_data = proc{|data| protocol_connection.write(data) }
    else
      @read_data, @raise_on_write = args
    end
    @write_exception = RuntimeError.new('test fail')
  end

  def read_data
    @read_data.kind_of?(Proc) ? @read_data.call : @read_data
  end

  def write_data(data)
    if @raise_on_write
      @raise_on_write = false
      raise @write_exception
    end
    @response = Sanford::Protocol::Response.parse(data)
  end

  def close_write
    @write_stream_closed = true
  end

  def request
    @request ||= Sanford::Protocol::Request.parse(self.read_data)
  end

end
