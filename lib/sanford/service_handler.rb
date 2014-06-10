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

    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module InstanceMethods

      def initialize(runner)
        @sanford_runner = runner
      end

      def init
        self.run_callback 'before_init'
        self.init!
        self.run_callback 'after_init'
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

      # Helpers

      def render(path, options = nil)
        options ||= {}
        get_engine(path, options['source'] || Sanford.config.template_source).render(
          path,
          self,
          options['locals'] || {}
        )
      end

      def run_handler(handler_class, params = nil)
        handler_class.run(params || {}, self.logger)
      end

      def halt(*args); @sanford_runner.halt(*args); end
      def request;     @sanford_runner.request;     end
      def params;      self.request.params;         end
      def logger;      @sanford_runner.logger;      end

      def run_callback(callback)
        (self.class.send("#{callback}_callbacks") || []).each do |callback|
          self.instance_eval(&callback)
        end
      end

      private

      def get_engine(path, source)
        source.engines[File.extname(get_template(path, source))[1..-1] || '']
      end

      def get_template(path, source)
        Dir.glob("#{Pathname.new(source.path).join(path.to_s)}.*").first.to_s
      end

    end

    module ClassMethods

      def run(params = nil, logger = nil)
        Sanford.config.runner.run(self, params || {}, logger)
      end

      def before_init_callbacks; @before_init_callbacks ||= []; end
      def after_init_callbacks;  @after_init_callbacks  ||= []; end
      def before_run_callbacks;  @before_run_callbacks  ||= []; end
      def after_run_callbacks;   @after_run_callbacks   ||= []; end

      def before_init(&block); self.before_init_callbacks << block; end
      def after_init(&block);  self.after_init_callbacks  << block; end
      def before_run(&block);  self.before_run_callbacks  << block; end
      def after_run(&block);   self.after_run_callbacks   << block; end
      def prepend_before_init(&block); self.before_init_callbacks.unshift(block); end
      def prepend_after_init(&block);  self.after_init_callbacks.unshift(block);  end
      def prepend_before_run(&block);  self.before_run_callbacks.unshift(block);  end
      def prepend_after_run(&block);   self.after_run_callbacks.unshift(block);   end

    end

  end

end
