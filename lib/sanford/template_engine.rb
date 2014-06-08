require 'pathname'

module Sanford

  class TemplateEngine

    attr_reader :source_path, :opts

    def initialize(opts = nil)
      @opts = opts || {}
      @source_path = Pathname.new(@opts['source_path'].to_s)
    end

    def render(path, scope)
      raise NotImplementedError
    end

  end

  class NullTemplateEngine < TemplateEngine

    def render(path, scope)
      template_file = self.source_path.join(path).to_s
      unless File.exists?(template_file)
        raise ArgumentError, "template file `#{template_file}` does not exist"
      end
      File.read(template_file)
    end

  end

end
