require 'ns-options'
require 'pathname'

require 'sanford/exception_handler'
require 'sanford/host_configuration'
require 'sanford/logger'

module Sanford

  class HostConfiguration < NsOptions::Struct.new

    option :name,             String
    option :ip,               String,   :default => '0.0.0.0'
    option :port,             Integer
    option :pid_dir,          Pathname, :default => Dir.pwd
    option :logger,                     :default => proc{ Sanford::NullLogger.new }
    option :verbose_logging,            :default => true

    option :exception_handler,        :default => Sanford::ExceptionHandler
    option :versioned_services, Hash, :default => {}

    def initialize(host_class, options = nil)
      @host_class = host_class
      self.name = host_class.to_s

      self.apply(options || {})
    end

  end

end
