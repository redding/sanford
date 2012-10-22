# Sanford's Hosts class is a singleton that provides all the logic for
# registering and looking up hosts. This is mostly a glorified `Hash` with a few
# convenience methods. When a host is added, a registered name is automatically
# derived from it and used. The `first` and `find` method are convenient lookup
# methods that return the service host along with it's registered name.
#
require 'set'
require 'singleton'

module Sanford

  class Hosts
    include Singleton

    attr_reader :set

    def initialize
      @set = Set.new
    end

    def add(host_class)
      @set << host_class
    end

    def find(name)
      self.set.detect{|host_class| host_class.name == name }
    end

    def first
      self.set.first
    end

    def empty?
      self.set.empty?
    end

    def clear
      self.set.clear
    end

    def self.method_missing(method, *args, &block)
      self.instance.send(method, *args, &block)
    end

    def self.respond_to?(method)
      super || self.instance.respond_to?(method)
    end

  end

end
