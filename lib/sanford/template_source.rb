require 'sanford/template_engine'

module Sanford

  class TemplateSource

    DISALLOWED_ENGINE_EXTS = [ '.rb' ]

    DisallowedEngineExtError = Class.new(ArgumentError)

    attr_reader :path, :engines

    def initialize(path)
      @path = path.to_s
      @default_opts = { 'source_path' => @path }
      @engines = Hash.new{ |h,k| Sanford::NullTemplateEngine.new(@default_opts) }
    end

    def engine(input_ext, engine_class, registered_opts = nil)
      if DISALLOWED_ENGINE_EXTS.include?(".#{input_ext}")
        raise DisallowedEngineExtError, "`#{input_ext}` is disallowed as an"\
                                        " engine extension."
      end
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
