# A bunch of service handler examples. These are defined to implement certain
# edge cases and are for specific tests within the test suite.
#

class StaticServiceHandler
  include Sanford::ServiceHandler

  # builds with the same request and logger always, just for convenience

  def initialize(logger = nil, request = nil)
    request ||= Sanford::Protocol::Request.new('v1', 'name', {})
    super(logger || Sanford::NullLogger.new, request)
  end

end

class ManualThrowServiceHandler < StaticServiceHandler

  def run!
    throw(:halt, 'halted!')
  end

end

class HaltWithServiceHandler < StaticServiceHandler

  def initialize(halt_with)
    request = Sanford::Protocol::Request.new('v1', 'name', {
      'halt_with' => halt_with.dup
    })
    super(Sanford::NullLogger.new, request)
  end

  def run!
    params['halt_with'].tap do |halt_with|
      halt(halt_with.delete(:code), halt_with)
    end
  end

end

class NoopServiceHandler < StaticServiceHandler

  # simply overwrites the default `run!` so it doesn't error

  def run!
    # nothing!
  end

end

class FlaggedServiceHandler < NoopServiceHandler

  # flags a bunch of methods as they are run by setting instance variables

  FLAGGED_METHODS = {
    'init'        => :init_called,
    'init!'       => :init_bang_called,
    'run!'        => :run_bang_called,
    'before_run'  => :before_run_called,
    'after_run'   => :after_run_called
  }
  FLAGS = FLAGGED_METHODS.values

  attr_reader *FLAGS

  def initialize(*passed)
    super
    FLAGS.each{|name| self.instance_variable_set("@#{name}", false) }
  end

  FLAGGED_METHODS.each do |method_name, instance_variable_name|

    # def before_run
    #   super
    #   @before_run_called = true
    # end
    define_method(method_name) do
      super
      self.instance_variable_set("@#{instance_variable_name}", true)
    end

  end

end

class ConfigurableServiceHandler < FlaggedServiceHandler

  def initialize(options = {})
    @options = options
    super
  end

  def before_run
    super
    if @options[:before_run]
      self.instance_eval(&@options[:before_run])
    end
  end

  def run!
    super
    if @options[:run!]
      self.instance_eval(&@options[:run!])
    end
  end

  def after_run
    super
    if @options[:after_run]
      self.instance_eval(&@options[:after_run])
    end
  end

end
