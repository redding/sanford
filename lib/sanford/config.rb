require 'ns-options'
require 'pathname'
require 'sanford/logger'
require 'sanford/runner'
require 'sanford/template_source'

module Sanford

  class Config
    include NsOptions::Proxy

    option :services_file,  Pathname, :default => proc{ ENV['SANFORD_SERVICES_FILE'] }
    option :logger,                   :default => proc{ Sanford::NullLogger.new }
    option :runner,                   :default => proc{ Sanford::DefaultRunner }

    attr_reader :template_source

    def initialize
      super
      @template_source = NullTemplateSource.new
    end

    def set_template_source(path, &block)
      @template_source = TemplateSource.new(path).tap{ |s| block.call(s) if block }
    end

  end

end
