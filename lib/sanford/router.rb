require 'sanford/route'

module Sanford

  class Router

    attr_reader :routes

    def initialize(&block)
      @routes = []
      self.instance_eval(&block) if !block.nil?
    end

    def service_handler_ns(value = nil)
      @service_handler_ns = value if !value.nil?
      @service_handler_ns
    end

    def service(name, handler_name)
      if self.service_handler_ns && !(handler_name =~ /^::/)
        handler_name = "#{self.service_handler_ns}::#{handler_name}"
      end

      @routes.push(Sanford::Route.new(name, handler_name))
    end

    def validate!
      self.routes.each(&:validate!)
      true
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} " \
        "@service_handler_ns=#{self.service_handler_ns.inspect}>"
    end

  end

end
