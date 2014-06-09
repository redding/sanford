require 'sanford/version'
require 'sanford/config'
require 'sanford/hosts'
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
    @hosts ||= Sanford::Hosts.new
    require self.config.services_file
  end

  def self.register(host)
    @hosts.add(host)
  end

  def self.hosts
    @hosts
  end

end
