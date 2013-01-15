module Sanford

  class HostVersionGroup
    attr_reader :name, :services

    def initialize(name, &definition_block)
      @name = name
      @services = {}
      self.instance_eval(&definition_block)
    end

    def service_handler_ns(value = nil)
      @service_handler_ns = value if value
      @service_handler_ns
    end

    def service(service_name, handler_class_name)
      if self.service_handler_ns && !(handler_class_name =~ /^::/)
        handler_class_name = "#{self.service_handler_ns}::#{handler_class_name}"
      end
      @services[service_name] = handler_class_name
    end

    def to_hash
      { self.name => self.services }
    end

  end

end
