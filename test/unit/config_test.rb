require 'assert'

module Sanford::Config

  class BaseTest < Assert::Context
    desc "Sanford::Config"
    subject{ Sanford::Config }

    should have_instance_methods :hosts, :services_config, :find_host
  end

  class FindHostTest < BaseTest
    desc "find_host"
    setup do
      Test::Environment.store_and_clear_hosts
      Sanford::Config.hosts.add(NotNamedHost)
      Sanford::Config.hosts.add(NamedHost)
      Sanford::Config.hosts.add(BadlyNamedHost)
    end
    teardown do
      Test::Environment.restore_hosts
    end

    should "allow finding hosts by their class name or configured name" do
      assert_includes NotNamedHost, subject.hosts
      assert_includes NamedHost,    subject.hosts
      assert_equal NotNamedHost,  subject.find_host('NotNamedHost')
      assert_equal NamedHost,     subject.find_host('NamedHost')
      assert_equal NamedHost,     subject.find_host('named_host')
    end
    should "check class name before configured name" do
      assert_includes BadlyNamedHost, subject.hosts
      assert_equal NotNamedHost, subject.find_host('NotNamedHost')
    end
  end

  # Using this syntax because these classes need to be defined as top-level
  # constants for ease in using their class names in the tests

  ::NotNamedHost = Class.new do
    include Sanford::Host
  end

  ::NamedHost = Class.new do
    include Sanford::Host
    name 'named_host'
  end

  ::BadlyNamedHost = Class.new do
    include Sanford::Host
    name 'NotNamedHost'
  end

end
