require 'assert'
require 'sanford/server_data'

require 'sanford/route'

class Sanford::ServerData

  class UnitTests < Assert::Context
    desc "Sanford::ServerData"
    setup do
      @orig_ip_env_var    = ENV['SANFORD_IP']
      @orig_port_env_var  = ENV['SANFORD_PORT']
      @orig_label_env_var = ENV['SANFORD_PROCESS_LABEL']
      ENV.delete('SANFORD_IP')
      ENV.delete('SANFORD_PORT')
      ENV.delete('SANFORD_PROCESS_LABEL')
      ENV.delete('SANFORD_DEBUG')

      @route = Sanford::Route.new(Factory.string, TestHandler.to_s).tap(&:validate!)

      @config_hash = {
        :name                => Factory.string,
        :ip                  => Factory.string,
        :port                => Factory.integer,
        :pid_file            => Factory.file_path,
        :shutdown_timeout    => Factory.integer,
        :worker_class        => Class.new,
        :worker_params       => { Factory.string => Factory.string },
        :num_workers         => Factory.integer,
        :error_procs         => Factory.integer(3).times.map{ proc{} },
        :template_source     => Factory.string,
        :logger              => Factory.string,
        :router              => Factory.string,
        :receives_keep_alive => Factory.boolean,
        :verbose_logging     => Factory.boolean,
        :routes              => [@route]
      }
      @server_data = Sanford::ServerData.new(@config_hash)
    end
    teardown do
      ENV['SANFORD_IP']            = @orig_ip_env_var
      ENV['SANFORD_PORT']          = @orig_port_env_var
      ENV['SANFORD_PROCESS_LABEL'] = @orig_label_env_var
      ENV['SANFORD_DEBUG']         = @orig_debug_env_var
    end
    subject{ @server_data }

    should have_accessors :ip, :port
    should have_readers :name, :pid_file, :shutdown_timeout
    should have_readers :worker_class, :worker_params, :num_workers
    should have_readers :error_procs, :template_source, :logger, :router
    should have_readers :receives_keep_alive, :verbose_logging
    should have_readers :debug, :dtcp_logger, :routes, :process_label
    should have_imeths :route_for

    should "know its attrs" do
      h = @config_hash
      assert_equal h[:name],     subject.name
      assert_equal h[:ip],       subject.ip
      assert_equal h[:port],     subject.port
      assert_equal h[:pid_file], subject.pid_file

      assert_equal h[:shutdown_timeout], subject.shutdown_timeout

      assert_equal h[:worker_class],    subject.worker_class
      assert_equal h[:worker_params],   subject.worker_params
      assert_equal h[:num_workers],     subject.num_workers
      assert_equal h[:error_procs],     subject.error_procs
      assert_equal h[:template_source], subject.template_source
      assert_equal h[:logger],          subject.logger
      assert_equal h[:router],          subject.router

      assert_equal h[:receives_keep_alive], subject.receives_keep_alive
      assert_equal h[:verbose_logging],     subject.verbose_logging

      assert_false subject.debug
      assert_nil   subject.dtcp_logger

      exp = { @route.name => @route }
      assert_equal exp, subject.routes
    end

    should "use ip and port env vars if they are set" do
      ENV['SANFORD_IP']   = Factory.string
      ENV['SANFORD_PORT'] = Factory.integer.to_s
      server_data = Sanford::ServerData.new(@config_hash)
      assert_equal ENV['SANFORD_IP'],        server_data.ip
      assert_equal ENV['SANFORD_PORT'].to_i, server_data.port

      ENV['SANFORD_IP']   = ""
      ENV['SANFORD_PORT'] = ""
      server_data = Sanford::ServerData.new(@config_hash)
      assert_equal @config_hash[:ip],   server_data.ip
      assert_equal @config_hash[:port], server_data.port
    end

    should "know its process label" do
      ENV['SANFORD_PROCESS_LABEL'] = Factory.string
      server_data = Sanford::ServerData.new(@config_hash)
      exp = ENV['SANFORD_PROCESS_LABEL']
      assert_equal exp, server_data.process_label

      ENV['SANFORD_PROCESS_LABEL'] = ""
      server_data = Sanford::ServerData.new(@config_hash)
      exp = "#{@config_hash[:name]}-#{@config_hash[:ip]}-#{@config_hash[:port]}"
      assert_equal exp, server_data.process_label

      ENV.delete('SANFORD_PROCESS_LABEL')
      server_data = Sanford::ServerData.new(@config_hash)
      exp = "#{@config_hash[:name]}-#{@config_hash[:ip]}-#{@config_hash[:port]}"
      assert_equal exp, server_data.process_label
    end

    should "use the debug env var if set" do
      ENV['SANFORD_DEBUG'] = Factory.string
      server_data = Sanford::ServerData.new(@config_hash)
      assert_true server_data.debug
      assert_equal server_data.logger, server_data.dtcp_logger
    end

    should "look up a route using `route_for`" do
      assert_equal @route, subject.route_for(@route.name)
    end

    should "raise a not found error using `route_for` with an invalid name" do
      assert_raises(Sanford::NotFoundError) do
        subject.route_for(Factory.string)
      end
    end

    should "default its attrs when they aren't provided" do
      server_data = Sanford::ServerData.new
      assert_nil server_data.name
      assert_nil server_data.ip
      assert_nil server_data.port
      assert_nil server_data.pid_file
      assert_nil server_data.shutdown_timeout

      assert_nil server_data.worker_class
      assert_equal({}, server_data.worker_params)
      assert_nil server_data.num_workers

      assert_equal [], server_data.error_procs

      assert_nil server_data.template_source
      assert_nil server_data.logger
      assert_nil server_data.router

      assert_false server_data.receives_keep_alive
      assert_false server_data.verbose_logging

      assert_false server_data.debug
      assert_nil server_data.dtcp_logger

      assert_equal({}, server_data.routes)
    end

  end

  TestHandler = Class.new

end
