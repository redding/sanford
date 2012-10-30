module Sanford
  module Test

    module Helpers
      module_function

      def parse_response(bytes)
        bytes = bytes.dup
        serialized_size = bytes.slice!(0, Sanford::Response.number_size_bytes)
        size = Sanford::Response.deserialize_size(serialized_size)
        serialized_version = bytes.slice!(0, Sanford::Response.number_version_bytes)
        serialized_response = bytes.slice!(0, size)
        response = Sanford::Response.parse(serialized_response)
        [ response, size, serialized_version ]
      end

    end

  end
end
