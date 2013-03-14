class FakeConnection

  attr_reader :read_data, :response, :write_stream_closed

  def self.with_request(version, name, params = {}, raise_on_write = false)
    request = Sanford::Protocol::Request.new(version, name, params)
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
  end

  def read_data
    @read_data.kind_of?(Proc) ? @read_data.call : @read_data
  end

  def write_data(data)
    if @raise_on_write
      @raise_on_write = false
      raise 'test fail'
    end
    @response = Sanford::Protocol::Response.parse(data)
  end

  def close_write
    @write_stream_closed = true
  end

end
