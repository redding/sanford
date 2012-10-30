require 'ns-options'
require 'pathname'
require 'set'

ENV['SANFORD_SERVICES_CONFIG'] ||= 'config/services'

module Sanford

  module Config
    include NsOptions::Proxy

    option :hosts,            Set,      :default => []
    option :services_config,  Pathname, :default => ENV['SANFORD_SERVICES_CONFIG']

    def self.find_host(class_name)
      self.hosts.detect{|host_class| host_class.to_s == class_name.to_s }
    end

  end

end
