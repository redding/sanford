require 'sanford/runner'

module Sanford

  class SanfordRunner < Runner

    def run
      build_response do
        self.handler.sanford_run_callback 'before'
        self.handler.sanford_init
        return_value = self.handler.sanford_run
        self.handler.sanford_run_callback 'after'
        return_value
      end
    end

  end

end
