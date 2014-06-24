require 'assert'
require 'sanford/config_file'

class Sanford::ConfigFile

  class UnitTests < Assert::Context
    desc "Sanford::ConfigFile"
    setup do
      @file_path = ROOT_PATH.join('test/support/config.sanford')
      @config_file = Sanford::ConfigFile.new(@file_path)
    end
    subject{ @config_file }

    should have_readers :server
    should have_imeths :run

    should "know its server" do
      assert_instance_of AppServer, subject.server
    end

    should "define constants in the file at the top-level binding" do
      assert_not_nil defined?(::TestConstant)
    end

    should "set its server using run" do
      fake_server = Factory.string
      subject.run fake_server
      assert_equal fake_server, subject.server
    end

    should "allow passing a path without the extension" do
      file_path = ROOT_PATH.join('test/support/config')
      config_file = nil

      assert_nothing_raised do
        config_file = Sanford::ConfigFile.new(file_path)
      end
      assert_instance_of AppServer, config_file.server
    end

    should "raise no config file error when the file doesn't exist" do
      assert_raises(NoConfigFileError) do
        Sanford::ConfigFile.new(Factory.file_path)
      end
    end

    should "raise a no server error when the file doesn't call run" do
      file_path = ROOT_PATH.join('test/support/config_no_run.sanford')
      assert_raises(NoServerError){ Sanford::ConfigFile.new(file_path) }
    end

    should "raise a no server error when the file provides an invalid server" do
      file_path = ROOT_PATH.join('test/support/config_invalid_run.sanford')
      assert_raises(NoServerError){ Sanford::ConfigFile.new(file_path) }
    end

  end

end
