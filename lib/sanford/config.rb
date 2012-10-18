require 'ns-options'
require 'pathname'

ENV['SANFORD_SERVICES_CONFIG'] ||= 'config/services'

module Sanford

  module Config
    include NsOptions::Proxy

    option :services_config,  Pathname, :default => ENV['SANFORD_SERVICES_CONFIG']

  end

end
