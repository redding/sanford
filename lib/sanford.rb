module Sanford; end

require 'ns-options'
require 'pathname'
require 'set'

require 'sanford/host'
require 'sanford/server'
require 'sanford/service_handler'
require 'sanford/version'

ENV['SANFORD_SERVICES_FILE'] ||= 'config/services'

module Sanford

  def self.register(host)
    @hosts.add(host)
  end

  def self.hosts
    @hosts
  end

  def self.config
    Sanford::Config
  end

  def self.configure(&block)
    self.config.define(&block)
    self.config
  end

  def self.init
    @hosts ||= Hosts.new
    require self.config.services_file
  end

  module Config
    include NsOptions::Proxy
    option :services_file,  Pathname, :default => ENV['SANFORD_SERVICES_FILE']

  end

  class Hosts

    def initialize(values = [])
      @set = Set.new(values)
    end

    # We want class names to take precedence over a configured name, so that if
    # a user specifies a specific class, they always get it
    def find(name)
      self.find_by_class_name(name) || self.find_by_name(name)
    end

    def find_by_class_name(class_name)
      @set.detect{|host_class| host_class.to_s == class_name.to_s }
    end

    def find_by_name(name)
      @set.detect{|host_class| host_class.name == name.to_s }
    end

    def method_missing(method, *args, &block)
      @set.send(method, *args, &block)
    end

    def respond_to?(method)
      super || @set.respond_to?(method)
    end

  end

end
