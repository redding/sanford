require 'sanford/config'
require 'sanford/manager'
require 'sanford/host'
require 'sanford/version'

module Sanford

  def self.config
    Sanford::Config
  end

  def self.configure(&block)
    self.config.define(&block)
    self.config
  end

  def self.init
    begin
      require self.config.services_config
    rescue LoadError
      raise(Sanford::NoServicesConfigFile.new(self.config.services_config))
    end
  end

  class BadRequest < RuntimeError; end
  class NotFound < RuntimeError; end

  class NoHost < RuntimeError
    attr_reader :message

    def initialize(host_name)
      @message = if Sanford.config.hosts.empty?
        "No hosts have been defined. " \
        "Please define a host before trying to run Sanford."
      else
        "A host couldn't be found with the name #{host_name.inspect}. "
      end
    end
  end

  class NoServicesConfigFile < RuntimeError
    attr_reader :message

    def initialize(file_path)
      @message = "Sanford couldn't require the file '#{file_path}', please make sure it exists " \
        "or modify `Sanford::Config.services_config`."
    end
  end

  class InvalidHost < RuntimeError
    attr_reader :message

    def initialize(host)
      @message = "A port must be configured or provided to build an instance of '#{host}'"
    end
  end

  class NoHandlerClass < RuntimeError
    attr_reader :message

    def initialize(host, handler_class_name)
      @message = "Sanford couldn't find the service handler '#{handler_class_name}'." \
        "It doesn't exist or hasn't been required in yet."
    end
  end

end
