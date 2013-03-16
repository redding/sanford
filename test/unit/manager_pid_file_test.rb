require 'assert'
require 'sanford/cli'

class Sanford::Manager::PIDFile

  class BaseTest < Assert::Context
    desc "Sanford::Manager::PIDFile"
    setup do
      @pid_file_path = File.join(ROOT, "tmp/my.pid")
      @pid_file = Sanford::Manager::PIDFile.new(@pid_file_path)
    end
    teardown do
      FileUtils.rm_rf(@pid_file_path)
    end
    subject{ @pid_file }

    should have_instance_methods :pid, :to_s, :write, :remove

    should "return it's path with #to_s" do
      assert_equal @pid_file_path, subject.to_s
    end

    should "write the pid file with #write" do
      subject.write

      assert_file_exists @pid_file_path
      assert_equal "#{Process.pid}\n", File.read(@pid_file_path)
    end

    should "return the value stored in the pid value with #pid" do
      subject.write

      assert_equal Process.pid, subject.pid
    end

    should "remove the file with #remove" do
      subject.write
      subject.remove

      assert_not File.exists?(@pid_file_path)
    end

    should "complain nicely if the pid file dir doesn't exist or isn't writeable" do
      pid_file_path = 'does/not/exist.pid'

      err = nil
      begin
        Sanford::Manager::PIDFile.new(pid_file_path)
      rescue Exception => err
      end

      assert err
      assert_kind_of RuntimeError, err
      assert_includes File.dirname(pid_file_path), err.message
    end

  end

end
