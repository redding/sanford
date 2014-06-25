require 'sanford/runner'

module Sanford

  class SanfordRunner < Sanford::Runner

    def initialize(handler_class, request, server_data)
      @request         = request
      @params          = @request.params
      @logger          = server_data.logger
      @template_source = server_data.template_source

      super(handler_class)
    end

    # call the handler init and the handler run - if the init halts, run won't
    # be called.

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
