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

    DEFAULT_STATUS_CODE = 200.freeze
    DEFAULT_STATUS_MSG  = nil.freeze
    DEFAULT_DATA        = nil.freeze

    attr_reader :handler_class, :handler
    attr_reader :logger, :router, :template_source
    attr_reader :request, :params

    def initialize(handler_class, args = nil)
      @status_code, @status_msg, @data = nil, nil, nil

      args ||= {}
      @logger          = args[:logger] || Sanford::NullLogger.new
      @router          = args[:router] || Sanford::Router.new
      @template_source = args[:template_source] || Sanford::NullTemplateSource.new
      @request         = args[:request]
      @params          = args[:params] || {}

      @handler_class = handler_class
      @handler = @handler_class.new(self)
    end

    def run
      raise NotImplementedError
    end

    def to_response
      Sanford::Protocol::Response.new(
        [@status_code || DEFAULT_STATUS_CODE, @status_msg || DEFAULT_STATUS_MSG],
        @data.nil? ? DEFAULT_DATA : @data
      )
    end

    def status(*args)
      if !args.empty?
        @status_msg  = (args.pop)[:message] if args.last.kind_of?(::Hash)
        @status_code = args.first           if !args.empty?
      end
      [@status_code, @status_msg]
    end

    def data(value = nil)
      @data = value if !value.nil?
      @data
    end

    def halt(*args)
      self.status(*args)
      self.data((args.pop)[:data]) if args.last.kind_of?(::Hash)
      throw :halt
    end

    def render(path, locals = nil)
      self.data(self.template_source.render(path, self.handler, locals || {}))
    end

  end

end
