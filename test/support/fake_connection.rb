class FakeConnection

  attr_reader :read_data, :response

  def self.with_request(version, name, params = {}, raise_on_write = false)
    request = Sanford::Protocol::Request.new(version, name, params)
    self.new(request.to_hash, raise_on_write)
  end

  def initialize(read_data, raise_on_write = false)
    @raise_on_write = raise_on_write
    @read_data = read_data
  end

  def write_data(data)
    if @raise_on_write
      @raise_on_write = false
      raise 'test fail'
    end
    @response = Sanford::Protocol::Response.parse(data)
  end

end
