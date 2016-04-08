require 'pathname'
require 'sanford/logger'

module Sanford

  class TemplateEngine

    attr_reader :source_path, :logger, :opts

    def initialize(opts = nil)
      @opts = opts || {}
      @source_path = Pathname.new(@opts['source_path'].to_s)
      @logger = @opts['logger'] || Sanford::NullLogger.new
    end

    def render(name, service_handler, locals)
      raise NotImplementedError
    end

    def ==(other_engine)
      if other_engine.kind_of?(TemplateEngine)
        self.source_path == other_engine.source_path &&
        self.opts        == other_engine.opts
      else
        super
      end
    end

  end

  class NullTemplateEngine < TemplateEngine

    def render(name, service_handler, locals)
      template_file = self.source_path.join(name).to_s
      unless File.exists?(template_file)
        raise ArgumentError, "template file `#{template_file}` does not exist"
      end
      File.read(template_file)
    end

  end

end
