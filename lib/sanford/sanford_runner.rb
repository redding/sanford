require 'sanford/runner'

module Sanford

  class SanfordRunner < Runner

    def run
      catch(:halt) do
        self.handler.sanford_run_callback 'before'
        catch(:halt){ self.handler.sanford_init; self.handler.sanford_run }
        self.handler.sanford_run_callback 'after'
      end
      self.to_response
    end

  end

end
