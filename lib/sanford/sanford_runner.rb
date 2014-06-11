require 'sanford/runner'

module Sanford

  class SanfordRunner
    include Sanford::Runner

    # call the handler init and the handler run - if the init halts, run won't
    # be called.

    def run!
      self.handler.init
      response_args = self.handler.run
      response_args
    end

  end

end
