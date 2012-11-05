require 'sanford/response'

module Sanford

  module ServiceHandler

    def self.constantize(class_name)
      names = class_name.to_s.split('::').reject{|name| name.empty? }
      klass = names.inject(Object) do |constant, name|
        constant.const_get(name)
      end
      klass == Object ? false : klass
    rescue NameError
      false
    end

    attr_reader :logger, :request

    def initialize(logger, request)
      @logger = logger
      @request = request
    end

    def init
      self.init!
    end

    def init!
    end

    def run
      result = self.run_callback 'before_run'
      result ||= catch(:halt) do
        self.init
        returned_value = self.run!
        [ :success, returned_value ]
      end
      after_result = self.run_callback 'after_run'
      (result = after_result) if after_result
      result
    end

    def run!
      raise NotImplementedError
    end

    def before_run
    end

    def after_run
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @request=#{self.request.inspect}>"
    end

    protected

    def halt(status, options = nil)
      options ||= {}
      status = Sanford::Response::Status.new(status, options[:message])
      throw(:halt, [ status, options[:result] ])
    end

    # Notes:
    # * Callbacks need to catch :halt incase the halt method is called. They
    #   also need to be sure to return nil if nothing is thrown, so that it
    #   is not considered as a response.
    def run_callback(name)
      catch(:halt) do
        self.send(name.to_s)
        nil
      end
    end

  end

end
