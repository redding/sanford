require 'assert'

class Sanford::Message

  class BaseTest < Assert::Context
    desc "Sanford::Message"
    setup do
      @message = Sanford::Message.new({ 'something' => true })
    end
    subject{ @message }

    should have_instance_methods :body, :serialize
    should have_class_methods :parse, :serialize_size, :deserialize_size, :serialize_body,
      :deserialize_body

    should "convert the message to a valid binary format with #serialize" do
      result = subject.serialize

      serialized_size = result.slice!(0, Sanford::Message.number_size_bytes)
      size = serialized_size.unpack('N').first
      serialized_version = result.slice!(0, Sanford::Message.number_version_bytes)
      version = serialized_version.unpack('C').first
      serialized_body = result.slice!(0, size)
      body = ::BSON.deserialize(serialized_body)

      assert_equal 17, size
      assert_equal Sanford::Message.protocol_version, version
      assert_equal({ 'something' => true }, body)
    end

    should "serialize and deserialize a size integer with #serialize_size and #deserialize_size" do
      size = 4589
      serialized_size = subject.class.serialize_size(size)

      assert_kind_of String, serialized_size
      assert_equal 4, serialized_size.bytesize

      deserialized_size = subject.class.deserialize_size(serialized_size)

      assert_equal size, deserialized_size
    end

    should "serialize and deserialize a body hash with #serialize_body and #deserialize_body" do
      body = { 'integer' => 1, 'string' => 'test', 'boolean' => false, 'nil' => nil }
      serialized_body = subject.class.serialize_body(body)

      assert_kind_of String, serialized_body

      deserialized_body = subject.class.deserialize_body(serialized_body)

      assert_equal body, deserialized_body
    end
  end

  class WithNilBodyValuesTest < BaseTest
    desc "with nil body values"
    setup do
      @message = Sanford::Message.new({ 'null' => nil })
    end

    should "not rejected any nil values from the it's body" do
      assert_equal({}, subject.body)
    end
  end

end
