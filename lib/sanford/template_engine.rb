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

    def render(template_name, service_handler, locals)
      paths = Dir.glob(self.source_path.join("#{template_name}*"))
      if paths.size > 1
        raise ArgumentError, "#{template_name.inspect} matches more than one " \
                             "file, consider using a more specific template name"
      end
      if paths.size < 1
        raise ArgumentError, "a template file named #{template_name.inspect} " \
                             "does not exist"
      end
      File.read(paths.first.to_s)
    end

  end

end
