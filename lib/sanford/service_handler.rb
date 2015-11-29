require 'much-plugin'

module Sanford

  module ServiceHandler
    include MuchPlugin

    plugin_included do
      extend ClassMethods
      include InstanceMethods
    end

    module InstanceMethods

      def initialize(runner)
        @sanford_runner = runner
      end

      def sanford_init
        self.sanford_run_callback 'before_init'
        self.init!
        self.sanford_run_callback 'after_init'
      end

      def init!
      end

      def sanford_run
        self.sanford_run_callback 'before_run'
        data = self.run!
        self.sanford_run_callback 'after_run'
        [200, data]
      end

      def run!
      end

      def sanford_run_callback(callback)
        (self.class.send("#{callback}_callbacks") || []).each do |callback|
          self.instance_eval(&callback)
        end
      end

      def inspect
        reference = '0x0%x' % (self.object_id << 1)
        "#<#{self.class}:#{reference} @request=#{request.inspect}>"
      end

      def ==(other_handler)
        self.class == other_handler.class
      end

      private

      # Helpers

      # utils
      def logger; @sanford_runner.logger; end

      # request
      def request; @sanford_runner.request; end
      def params;  @sanford_runner.params;  end

      # response
      def status(*args); @sanford_runner.status(*args); end
      def data(*args);   @sanford_runner.data(*args);   end
      def halt(*args);   @sanford_runner.halt(*args);   end
      def render(*args); @sanford_runner.render(*args); end

    end

    module ClassMethods

      def before_callbacks;      @before_callbacks      ||= []; end
      def after_callbacks;       @after_callbacks       ||= []; end
      def before_init_callbacks; @before_init_callbacks ||= []; end
      def after_init_callbacks;  @after_init_callbacks  ||= []; end
      def before_run_callbacks;  @before_run_callbacks  ||= []; end
      def after_run_callbacks;   @after_run_callbacks   ||= []; end

      def before(&block);      self.before_callbacks      << block; end
      def after(&block);       self.after_callbacks       << block; end
      def before_init(&block); self.before_init_callbacks << block; end
      def after_init(&block);  self.after_init_callbacks  << block; end
      def before_run(&block);  self.before_run_callbacks  << block; end
      def after_run(&block);   self.after_run_callbacks   << block; end

      def prepend_before(&block);      self.before_callbacks.unshift(block);      end
      def prepend_after(&block);       self.after_callbacks.unshift(block);       end
      def prepend_before_init(&block); self.before_init_callbacks.unshift(block); end
      def prepend_after_init(&block);  self.after_init_callbacks.unshift(block);  end
      def prepend_before_run(&block);  self.before_run_callbacks.unshift(block);  end
      def prepend_after_run(&block);   self.after_run_callbacks.unshift(block);   end

    end

    module TestHelpers

      def self.included(klass)
        require 'sanford/test_runner'
      end

      def test_runner(handler_class, args = nil)
        TestRunner.new(handler_class, args)
      end

      def test_handler(handler_class, args = nil)
        test_runner(handler_class, args).handler
      end

    end

  end

end
