require 'ostruct'
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

    # This method has very specific handling when before/after callbacks halt.
    # It should always return a response tuple: `[ status, data ]`
    # * If `before_run` halts, then the handler is not 'run' (it's `init` and
    #   `run` methods are not called) and it's response tuple is returned.
    # * If `after_run` halts, then it's response tuple is returned, even if
    #   calling `before_run` or 'running' the handler generated a response
    #   tuple.
    # * If `before_run` and `after_run` do not halt, then the response tuple
    #   from 'running' is used.
    def run
      response_tuple = self.run_callback 'before_run'
      response_tuple ||= catch(:halt) do
        self.init
        data = self.run!
        [ 200, data ]
      end
      after_response_tuple = self.run_callback 'after_run'
      (response_tuple = after_response_tuple) if after_response_tuple
      response_tuple
    end

    def run!
      raise NotImplementedError
    end

    def before_run
    end

    def after_run
    end

    def params
      self.request.params
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @request=#{self.request.inspect}>"
    end

    protected

    def halt(status, options = nil)
      options = OpenStruct.new(options || {})
      response_status = [ status, options.message ]
      throw(:halt, [ response_status, options.data ])
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
