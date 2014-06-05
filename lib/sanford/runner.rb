require 'ostruct'
require 'sanford-protocol'

module Sanford

  module Runner

    ResponseArgs = Struct.new(:status, :data)

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods

      attr_reader :handler_class, :request, :logger

      def initialize(handler_class, request, logger = nil)
        @handler_class, @request = handler_class, request
        @logger = logger || Sanford.config.logger
        @handler = @handler_class.new(self)
        self.init
      end

      def init
        self.init!
      end

      def init!
      end

      def run
        response_args = catch_halt{ self.run!(@handler) }
        Sanford::Protocol::Response.new(
          response_args.status,
          sanitize_response_data(response_args.data)
        )
      end

      def run!
        raise NotImplementedError
      end

      # It's best to keep what `halt` and `catch_halt` return in the same format.
      # Currently this is a `ResponseArgs` object. This is so no matter how the
      # block returns (either by throwing or running normally), you get the same
      # thing kind of object.

      def halt(status, options = nil)
        options = OpenStruct.new(options || {})
        response_status = [ status, options.message ]
        throw :halt, ResponseArgs.new(response_status, options.data)
      end

      def catch_halt(&block)
        catch(:halt){ ResponseArgs.new(*block.call) }
      end

      private

      # BSON errors serializing certain data types, specifically Date and DateTime
      # this recursively sanitizes any data types that cause BSON to error
      def sanitize_response_data(data)
        if data.kind_of?(::DateTime)
          sanitize_datetime_data(data)
        elsif data.kind_of?(::Date)
          sanitize_date_data(data)
        elsif data.kind_of?(::Array)
          data.map{ |v| sanitize_response_data(v) }
        elsif data.kind_of?(::Hash)
          data.each{ |k, v| data[k] = sanitize_response_data(v) }
          data
        else
          data
        end
      end

      def sanitize_date_data(date)
        ::Time.utc(
          date.year,
          date.month,
          date.day
        ) # copied from activesupport
      end

      def sanitize_datetime_data(datetime)
        ::Time.utc(
          datetime.year,
          datetime.month,
          datetime.day,
          datetime.hour,
          datetime.min,
          datetime.sec,
          datetime.sec_fraction * (RUBY_VERSION < '1.9' ? 86400000000 : 1000000)
        ) # copied from activesupport
      end

    end

    module ClassMethods

      def run(handler_class, params = nil, logger = nil)
        request = Sanford::Protocol::Request.new('name', params || {})
        self.new(handler_class, request, logger).run
      end

    end

  end

  class DefaultRunner
    include Sanford::Runner

    def run!(handler)
      handler.init
      handler.run
    end

  end

end
