namespace :bench do

  task :load do
    require 'bench/runner'
  end

  namespace :server do

    task :load do
      ENV['SANFORD_SERVICES_FILE'] = 'bench/services'
    end

    desc "Run the bench server"
    task :run => :load do
      Kernel.exec("bundle exec sanford run")
    end

    desc "Start a daemonized bench server"
    task :start => :load do
      Kernel.system("bundle exec sanford start")
    end

    desc "Stop the bench server"
    task :stop => :load do
      Kernel.system("bundle exec sanford stop")
    end

  end

  desc "Run a Benchmark report against the Benchmark server"
  task :report => :load do
    Bench::Runner.new.build_report
  end

  desc "Run Benchmark requests against the 'simple' service"
  task :simple, [ :times ] => :load do |t, args|
    runner = Bench::Runner.new(:output => '/dev/null')
    runner.benchmark_service('v1', 'simple', {}, args[:times] || 1, true)
  end

end
