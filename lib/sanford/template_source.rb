require 'sanford/logger'
require 'sanford/template_engine'

module Sanford

  class TemplateSource

    attr_reader :path, :engines

    def initialize(path, logger = nil)
      @path = path.to_s
      @default_opts = {
        'source_path' => @path,
        'logger'      => logger || Sanford::NullLogger.new
      }
      @engines = Hash.new do |hash, ext|
        # cache null template exts so we don't repeatedly call this block for
        # known null template exts
        hash[ext.to_s] = Sanford::NullTemplateEngine.new(@default_opts)
      end
      @engine_exts = []
    end

    def engine(input_ext, engine_class, registered_opts = nil)
      @engine_exts << input_ext.to_s
      engine_opts = @default_opts.merge(registered_opts || {})
      engine_opts['ext'] = input_ext.to_s
      @engines[input_ext.to_s] = engine_class.new(engine_opts)
    end

    def engine_for?(ext)
      @engine_exts.include?(ext.to_s)
    end

    def engine_for_template?(template_name)
      self.engine_for?(get_template_ext(template_name))
    end

    def render(template_name, service_handler, locals)
      engine = @engines[get_template_ext(template_name)]
      engine.render(template_name, service_handler, locals)
    end

    def partial(template_name, locals)
      engine = @engines[get_template_ext(template_name)]
      engine.partial(template_name, locals)
    end

    def ==(other_template_source)
      if other_template_source.kind_of?(TemplateSource)
        self.path    == other_template_source.path &&
        self.engines == other_template_source.engines
      else
        super
      end
    end

    private

    def get_template_ext(template_name)
      files = Dir.glob("#{File.join(@path, template_name.to_s)}*")
      if files.size > 1
        raise ArgumentError, "#{template_name.inspect} matches more than one " \
                             "file, consider using a more specific template name"
      end
      parse_ext(files.first.to_s)
    end

    def parse_ext(template_name)
      File.extname(template_name)[1..-1]
    end

  end

  class NullTemplateSource < TemplateSource

    def initialize(root = nil)
      super(root || '')
    end

  end

end
