require 'sanford/template_engine'

module Sanford

  class TemplateSource

    attr_reader :path, :engines

    def initialize(path)
      @path = path.to_s
      @default_opts = { 'source_path' => @path }
      @engines = Hash.new{ |h,k| Sanford::NullTemplateEngine.new(@default_opts) }
    end

    def engine(input_ext, engine_class, registered_opts = nil)
      engine_opts = @default_opts.merge(registered_opts || {})
      @engines[input_ext.to_s] = engine_class.new(engine_opts)
    end

  end

  class NullTemplateSource < TemplateSource

    def initialize
      super('')
    end

  end

end
