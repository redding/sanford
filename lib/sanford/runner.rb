# need to define class immediately b/c of circular requires:
# - runner -> router -> route -> sanford_runner -> runner
module Sanford; end
class Sanford::Runner; end

require 'sanford-protocol'
require 'sanford/logger'
require 'sanford/router'
require 'sanford/template_source'

module Sanford

  class Runner

    ResponseArgs = Struct.new(:status, :data)

    attr_reader :handler_class, :handler
    attr_reader :logger, :router, :template_source
    attr_reader :request, :params

    def initialize(handler_class, args = nil)
      @handler_class = handler_class
      @handler = @handler_class.new(self)

      args ||= {}
      @logger          = args[:logger] || Sanford::NullLogger.new
      @router          = args[:router] || Sanford::Router.new
      @template_source = args[:template_source] || Sanford::NullTemplateSource.new
      @request         = args[:request]
      @params          = args[:params] || {}
    end

    def run
      raise NotImplementedError
    end

    # It's best to keep what `halt` and `catch_halt` return in the same format.
    # Currently this is a `ResponseArgs` object. This is so no matter how the
    # block returns (either by throwing or running normally), you get the same
    # thing kind of object.

    def halt(status, options = nil)
      options ||= {}
      message = options[:message] || options['message']
      response_status = [ status, message ]
      response_data = options[:data] || options['data']
      throw :halt, ResponseArgs.new(response_status, response_data)
    end

    def render(path, locals = nil)
      self.template_source.render(path, self.handler, locals || {})
    end

    private

    def catch_halt(&block)
      catch(:halt){ ResponseArgs.new(*block.call) }
    end

    def build_response(&block)
      args = catch_halt(&block)
      Sanford::Protocol::Response.new(args.status, args.data)
    end

  end

end
