module Sanford

  module ServiceHandler

    def self.constantize(class_name)
      names = class_name.to_s.split('::')
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
      # logging
      # benchmarking
      # timeout
      self.run!
    end

  end

end
