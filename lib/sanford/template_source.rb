require 'sanford/logger'
require 'sanford/template_engine'

module Sanford

  class TemplateSource

    DISALLOWED_ENGINE_EXTS = [ 'rb' ]

    DisallowedEngineExtError = Class.new(ArgumentError)

    attr_reader :path, :engines

    def initialize(path, logger = nil)
      @path = path.to_s
      @default_opts = {
        'source_path' => @path,
        'logger'      => logger || Sanford::NullLogger.new
      }
      @engines = Hash.new{ |h,k| Sanford::NullTemplateEngine.new(@default_opts) }
    end

    def engine(input_ext, engine_class, registered_opts = nil)
      if DISALLOWED_ENGINE_EXTS.include?(input_ext)
        raise DisallowedEngineExtError, "`#{input_ext}` is disallowed as an"\
                                        " engine extension."
      end
      engine_opts = @default_opts.merge(registered_opts || {})
      @engines[input_ext.to_s] = engine_class.new(engine_opts)
    end

    def engine_for?(template_name)
      @engines.keys.include?(get_template_ext(template_name))
    end

    def render(template_path, service_handler, locals)
      engine = @engines[get_template_ext(template_path)]
      engine.render(template_path, service_handler, locals)
    end

    private

    def get_template_ext(template_path)
      files = Dir.glob("#{File.join(@path, template_path.to_s)}.*")
      files = files.reject{ |p| !@engines.keys.include?(parse_ext(p)) }
      parse_ext(files.first.to_s || '')
    end

    def parse_ext(template_path)
      File.extname(template_path)[1..-1]
    end

  end

  class NullTemplateSource < TemplateSource

    def initialize
      super('')
    end

  end

end
