require 'sanford/runner'

module Sanford

  class SanfordRunner
    include Sanford::Runner

    # call the handler init and the handler run - if the init halts, run won't
    # be called.

    def run!
      run_callbacks self.handler_class.before_callbacks
      self.handler.init
      response_args = self.handler.run
      run_callbacks self.handler_class.after_callbacks
      response_args
    end

    private

    def run_callbacks(callbacks)
      callbacks.each{ |proc| self.handler.instance_eval(&proc) }
    end

  end

end
