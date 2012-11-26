require 'ns-options'
require 'pathname'
require 'set'

ENV['SANFORD_SERVICES_CONFIG'] ||= 'config/services'

module Sanford

  module Config
    include NsOptions::Proxy

    option :hosts,            Set,      :default => []
    option :services_config,  Pathname, :default => ENV['SANFORD_SERVICES_CONFIG']

    # We want class names to take precedence over a configured name, so that if
    # a user specifies a specific class, they always get it
    def self.find_host(name)
      self.find_host_by_class_name(name) || self.find_host_by_name(name)
    end

    protected

    def self.find_host_by_class_name(class_name)
      self.hosts.detect{|host_class| host_class.to_s == class_name.to_s }
    end

    def self.find_host_by_name(name)
      self.hosts.detect{|host_class| host_class.name == name.to_s }
    end

  end

end
