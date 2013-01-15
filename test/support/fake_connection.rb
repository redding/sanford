class FakeConnection

  attr_reader :read_data, :response

  def self.with_request(version, name, params = {})
    request = Sanford::Protocol::Request.new(version, name, params)
    self.new(request.to_hash)
  end

  def initialize(read_data)
    @read_data = read_data
  end

  def write_data(data)
    @response = Sanford::Protocol::Response.parse(data)
  end

end
