require 'assert'
require 'sanford'

require 'ns-options/proxy'

module Sanford

  class UnitTests < Assert::Context
    desc "Sanford"
    subject{ Sanford }

    should have_imeths :config, :configure, :init, :register, :hosts

  end

  class ConfigTests < UnitTests
    desc "Config"
    subject{ Sanford::Config }

    should have_imeths :services_file, :logger, :runner

    should "be an NsOptions::Proxy" do
      assert_includes NsOptions::Proxy, subject
    end

  end

  class HostsTests < UnitTests
    desc "Hosts"
    setup do
      @hosts = Sanford::Hosts.new
    end
    subject{ @hosts }

    should have_instance_methods :add, :first, :find

  end

  class FindTests < HostsTests
    desc "find method"
    setup do
      @hosts.add ::NotNamedHost
      @hosts.add ::NamedHost
      @hosts.add ::BadlyNamedHost
    end

    should "allow finding hosts by their class name or configured name" do
      assert_includes ::NotNamedHost, subject
      assert_includes ::NamedHost, subject

      assert_equal ::NotNamedHost, subject.find('NotNamedHost')
      assert_equal ::NamedHost, subject.find('NamedHost')
      assert_equal ::NamedHost, subject.find('named_host')
    end

    should "prefer hosts with a matching class name over configured name" do
      assert_includes ::BadlyNamedHost, subject
      assert_equal NotNamedHost, subject.find('NotNamedHost')
    end

  end

  # Using this syntax because these classes need to be defined as top-level
  # constants for ease in using their class names in the tests

  ::NotNamedHost   = Class.new{ include Sanford::Host }
  ::NamedHost      = Class.new{ include Sanford::Host; name 'named_host' }
  ::BadlyNamedHost = Class.new{ include Sanford::Host; name 'NotNamedHost' }

end
