require 'assert'

class Sanford::Hosts

  class BaseTest < Assert::Context
    desc "Sanford::Hosts"
    setup do
      TestHelper.preserve_and_clear_hosts
      @hosts = Sanford::Hosts
    end
    teardown do
      TestHelper.restore_hosts
    end
    subject{ @hosts }

    should "be a singleton class" do
      assert_includes Singleton, subject.included_modules
    end
    should "proxy missing methods to it's instance" do
      assert_same subject.set, subject.instance.set
    end
  end

  class InstanceTest < BaseTest
    desc "instance"
    setup do
      @instance = Sanford::Hosts.instance
    end
    subject{ @instance }

    should have_instance_methods :set, :add, :find, :first

    should "register a host with #add" do
      dummy_host = FakeHost.new({ :name => 'dummy_host' })
      subject.add(dummy_host)

      assert_includes dummy_host, subject.set
    end

    should "return the first service host and it's registeterd name with #first" do
      dummy_host = FakeHost.new({ :name => 'dummy_host' })

      assert_nil subject.first

      subject.add(dummy_host)

      assert_equal dummy_host, subject.first
    end

    should "return the matching service host and it's registeterd name with #find" do
      dummy_host = FakeHost.new({ :name => 'dummy_host' })
      subject.add(dummy_host)

      assert_equal dummy_host, subject.find('dummy_host')
      assert_nil subject.find('some_other_host')
    end

  end

end
