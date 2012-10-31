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
      catch(:halt) do
        self.init
        returned_value = self.run!
        [ :success, returned_value ]
      end
    end

    def run!
      raise NotImplementedError
    end

    protected

    def halt(status, options = nil)
      options ||= {}
      status = Sanford::Response::Status.new(status, options[:message])
      throw(:halt, [ status, options[:result] ])
    end

  end

end
