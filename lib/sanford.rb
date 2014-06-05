require 'ns-options'
require 'pathname'
require 'set'

require 'sanford/version'
require 'sanford/host'
require 'sanford/logger'
require 'sanford/runner'
require 'sanford/server'
require 'sanford/service_handler'

ENV['SANFORD_SERVICES_FILE'] ||= 'config/services'

module Sanford

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

  def self.register(host)
    @hosts.add(host)
  end

  def self.hosts
    @hosts
  end

  module Config
    include NsOptions::Proxy
    option :services_file,  Pathname, :default => ENV['SANFORD_SERVICES_FILE']
    option :logger,                   :default => Sanford::NullLogger.new
    option :runner,                   :default => Sanford::DefaultRunner
  end

  class Hosts

    def initialize(values = [])
      @set = Set.new(values)
    end

    def method_missing(method, *args, &block)
      @set.send(method, *args, &block)
    end

    def respond_to?(method)
      super || @set.respond_to?(method)
    end

    # We want class names to take precedence over a configured name, so that if
    # a user specifies a specific class, they always get it
    def find(name)
      find_by_class_name(name) || find_by_name(name)
    end

    private

    def find_by_class_name(class_name)
      @set.detect{|host_class| host_class.to_s == class_name.to_s }
    end

    def find_by_name(name)
      @set.detect{|host_class| host_class.name == name.to_s }
    end

  end

end
