require 'sanford-protocol'

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

    def initialize(runner)
      @sanford_runner = runner
    end

    def init
      self.init!
    end

    def init!
    end

    def run
      self.run_callback 'before_run'
      data = self.run!
      self.run_callback 'after_run'
      [ 200, data ]
    end

    def run!
      raise NotImplementedError
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @request=#{self.request.inspect}>"
    end

    protected

    def before_run
    end

    def after_run
    end

    # Helpers

    def halt(*args)
      @sanford_runner.halt(*args)
    end

    def request
      @sanford_runner.request
    end

    def params
      self.request.params
    end

    def logger
      @sanford_runner.logger
    end

    def run_callback(callback)
      self.send(callback.to_s)
    end

  end

end
