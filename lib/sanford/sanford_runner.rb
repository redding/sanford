require 'sanford/runner'

module Sanford

  class SanfordRunner < Runner

    def run
      build_response do
        run_callbacks self.handler_class.before_callbacks
        self.handler.init
        return_value = self.handler.run
        run_callbacks self.handler_class.after_callbacks
        return_value
      end
    end

    private

    def run_callbacks(callbacks)
      callbacks.each{ |proc| self.handler.instance_eval(&proc) }
    end

  end

end
