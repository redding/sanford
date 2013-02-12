require 'assert'

require 'sanford/cli'

class Sanford::Manager::PIDFile

  class BaseTest < Assert::Context
    desc "Sanford::Manager::PIDFile"
    setup do
      @pid_file = Sanford::Manager::PIDFile.new("tmp/my.pid")
    end
    teardown do
      FileUtils.rm_rf("tmp/my.pid")
    end
    subject{ @pid_file }

    should have_instance_methods :pid, :to_s, :write, :remove

    should "return it's path with #to_s" do
      assert_equal "tmp/my.pid", subject.to_s
    end

    should "write the pid file with #write" do
      subject.write

      assert File.exists?("tmp/my.pid")
      assert_equal "#{Process.pid}\n", File.read("tmp/my.pid")
    end

    should "return the value stored in the pid value with #pid" do
      subject.write

      assert_equal Process.pid, subject.pid
    end

    should "remove the file with #remove" do
      subject.write
      subject.remove

      assert_not File.exists?("tmp/my.pid")
    end

  end

end
