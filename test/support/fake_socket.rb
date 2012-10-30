class FakeSocket
  attr_reader :read_stream, :write_stream

  def initialize
    @read_stream = []
    @write_stream = []
  end

  def request(*args)
    options = args.last.kind_of?(Hash) ? args.pop : {}
    name, version, params = args

    serialized_body = if options[:serialized_body]
      options[:serialized_body]
    else
      body = options[:body] ? options[:body] : Sanford::Request.new(name, version, params).body
      Sanford::Request.serialize_body(body)
    end
    size = serialized_body.bytesize
    serialized_size = Sanford::Request.serialize_size(size)
    version = options[:protocol_version] || Sanford::Request.protocol_version
    serialized_version = [ version ].pack('C')
    @read_stream << [ serialized_size, serialized_version, serialized_body ].join
  end

  def read(number_of_bytes)
    stream = @read_stream.first
    read, leftover = [ stream[0..(number_of_bytes - 1)], stream[number_of_bytes..-1] ]
    @read_stream.insert(0, leftover) unless leftover.empty?
    read
  end

  def write(bytes)
    @write_stream << bytes
  end

end
