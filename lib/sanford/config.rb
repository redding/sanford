require 'ns-options'
require 'pathname'
require 'sanford/logger'
require 'sanford/runner'

module Sanford

  module Config
    include NsOptions::Proxy

    option :services_file,  Pathname, :default => ENV['SANFORD_SERVICES_FILE']
    option :logger,                   :default => Sanford::NullLogger.new
    option :runner,                   :default => Sanford::DefaultRunner

  end

end
