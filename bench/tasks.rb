namespace :bench do

  task :load do
    require 'bench/runner'
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
