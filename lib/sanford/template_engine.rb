module Sanford

  class TemplateEngine

    attr_reader :opts

    def initialize(opts = nil)
      @opts = opts || {}
    end

    def render(path, scope)
      raise NotImplementedError
    end

  end

  class NullTemplateEngine < TemplateEngine

    def render(path, scope)
      template_file = path
      unless File.exists?(template_file)
        raise ArgumentError, "template file `#{template_file}` does not exist"
      end
      File.read(template_file)
    end

  end

end
