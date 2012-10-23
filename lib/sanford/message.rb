# Sanford's message class defines the communication protocol it uses. A message
# has a body and when serialized, is made of 3 parts: size, protocol version and
# the body. The message class acts as a common base for both requests and
# responses. It also provides methods for serializing and deserializing the
# different parts.
#
require 'bson'

module Sanford

  class Message

    def self.protocol_version
      001
    end

    def self.serialized_protocol_version
      @serialized_protocol_version ||= [ self.protocol_version ].pack('C')
    end

    def self.number_size_bytes
      4
    end

    def self.number_version_bytes
      1
    end

    def self.parse(serialized_body)
      self.deserialize_body(serialized_body)
    end

    def self.serialize_size(size)
      [ size.to_i ].pack('N')
    end

    # Notes:
    # * BSON returns a byte buffer when serializing. This doesn't always behave
    #   like a string, so we convert it to one.
    def self.serialize_body(body)
      ::BSON.serialize(body).to_s
    end

    def self.deserialize_size(serialized_size)
      serialized_size.to_s.unpack('N').first
    end

    # Notes:
    # * BSON returns an ordered hash when deserializing. This should be
    #   functionally equivalent to a regular hash.
    def self.deserialize_body(serialized_body)
      ::BSON.deserialize(serialized_body)
    end

    attr_reader :body

    # Notes:
    # * A message removes any nil valued keys in the body's top level of keys.
    #   This is to limit transferring useless data. No sub-hashes are affected.
    def initialize(body)
      @body = self.remove_nil_values(body)
    end

    def serialize
      serialized_body = self.class.serialize_body(self.body)
      serialized_size = self.class.serialize_size(serialized_body.size)
      [ serialized_size, self.class.serialized_protocol_version, serialized_body ].join
    end

    protected

    def remove_nil_values(body)
      body.inject({}) do |hash, (k, v)|
        hash.merge!({ k => v }) if !v.nil?
        hash
      end
    end

  end

end
