module Factory
  module_function

  SERVICE_HANDLER_FLAGS_MIXIN = Module.new do
    ATTRIBUTES = [ :init_called, :init_bang_called, :run_bang_called, :before_run_called,
      :after_run_called ]
    attr_reader *ATTRIBUTES

    def initialize(*passed)
      super
      ATTRIBUTES.each do |name|
        self.instance_variable_set("@#{name}", false)
      end
    end

    def init
      super
      @init_called = true
    end

    def init!
      @init_bang_called = true
    end

    def run!
      @run_bang_called = true
    end

    def before_run
      @before_run_called = true
    end

    def after_run
      @after_run_called = true
    end
  end

  def service_handler(options = nil, &block)
    options ||= {}
    options[:with_flags] = true if !options.has_key?(:with_flags)

    handler_class = Class.new do
      include Sanford::ServiceHandler
      (include SERVICE_HANDLER_FLAGS_MIXIN) if options[:with_flags]
    end
    handler_class.class_eval(&block) if block
    handler_class
  end

end
