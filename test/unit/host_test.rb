require 'assert'

module Sanford::Host

  class BaseTest < Assert::Context
    desc "Sanford::Host"
    setup do
      TestHelper.preserve_and_clear_hosts
      @host = Class.new do
        include Sanford::Host

        name 'anonymous_host'
      end
    end
    teardown do
      TestHelper.restore_hosts
    end
    subject{ @host }

    should have_instance_methods :name, :host_name_for

    should "have registered the class with sanford's known hosts" do
      assert_includes subject, Sanford::Hosts.set
    end
    should "be a singleton" do
      assert_includes Singleton, subject.included_modules
    end
    should "proxy methods to it's instance" do
      assert_equal subject.instance.name, subject.name
      assert subject.respond_to?(:configure)
    end
    should "generate a simplfied host name from a class name with #host_name_for" do
      assert_equal "my_host", subject.host_name_for("MyHost")
      assert_equal "apihost", subject.host_name_for("APIHost") # this is a known limitation
    end
  end

  class InstanceTest < BaseTest
    desc "instance"
    setup do
      @instance = @host.instance
    end
    subject{ @instance }

    should have_instance_methods :name, :config, :configure

    should "return an instance of Sanford::Host::Configuration with #config" do
      assert_instance_of Sanford::Host::Configuration, subject.config
    end
    should "allow reading and writing the name variable with #name" do
      assert_equal 'anonymous_host', subject.name

      subject.name('changed_name')

      assert_equal 'changed_name', subject.name
    end
    should "yield the config with #configure" do
      yielded = nil
      subject.configure{ yielded = self }
      assert_equal subject.config.host, yielded.host

      yielded = nil
      subject.configure{|c| yielded = c }
      assert_equal subject.config.port, yielded.port
    end
  end

end
