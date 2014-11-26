require 'assert'
require 'sanford/server_data'

require 'sanford/route'

class Sanford::ServerData

  class UnitTests < Assert::Context
    desc "Sanford::ServerData"
    setup do
      @name     = Factory.string
      @ip       = Factory.string
      @port     = Factory.integer
      @pid_file = Factory.file_path

      @receives_keep_alive = Factory.boolean

      @verbose_logging = Factory.boolean
      @logger          = Factory.string
      @template_source = Factory.string

      @init_procs  = [ proc{} ]
      @error_procs = [ proc{} ]

      @router = Factory.string
      @route  = Sanford::Route.new(Factory.string, TestHandler.to_s).tap(&:validate!)

      @server_data = Sanford::ServerData.new({
        :name     => @name,
        :ip       => @ip,
        :port     => @port,
        :pid_file => @pid_file,
        :receives_keep_alive => @receives_keep_alive,
        :verbose_logging => @verbose_logging,
        :logger          => @logger,
        :template_source => @template_source,
        :init_procs  => @init_procs,
        :error_procs => @error_procs,
        :router => @router,
        :routes => [ @route ]
      })
    end
    subject{ @server_data }

    should have_readers :name
    should have_readers :ip, :port
    should have_readers :pid_file
    should have_readers :receives_keep_alive
    should have_readers :verbose_logging, :logger, :template_source
    should have_readers :init_procs, :error_procs
    should have_readers :router, :routes

    should "know its attributes" do
      assert_equal @name,     subject.name
      assert_equal @ip,       subject.ip
      assert_equal @port,     subject.port
      assert_equal @pid_file, subject.pid_file

      assert_equal @receives_keep_alive, subject.receives_keep_alive

      assert_equal @verbose_logging, subject.verbose_logging
      assert_equal @logger,          subject.logger
      assert_equal @template_source, subject.template_source

      assert_equal @init_procs,  subject.error_procs
      assert_equal @error_procs, subject.error_procs

      assert_equal @router, subject.router
    end

    should "build a routes lookup hash" do
      expected = { @route.name => @route }
      assert_equal expected, subject.routes
    end

    should "allow lookup a route using `route_for`" do
      route = subject.route_for(@route.name)
      assert_equal @route, route
    end

    should "raise a not found error using `route_for` with an invalid name" do
      assert_raises(Sanford::NotFoundError) do
        subject.route_for(Factory.string)
      end
    end

    should "default its attributes when they aren't provided" do
      server_data = Sanford::ServerData.new
      assert_nil server_data.name
      assert_nil server_data.ip
      assert_nil server_data.port
      assert_nil server_data.pid_file

      assert_false server_data.receives_keep_alive

      assert_false server_data.verbose_logging
      assert_nil   server_data.logger
      assert_nil   server_data.template_source

      assert_equal [], server_data.init_procs
      assert_equal [], server_data.error_procs

      assert_nil       server_data.router
      assert_equal({}, server_data.routes)
    end

  end

  TestHandler = Class.new

end
