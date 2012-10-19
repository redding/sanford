namespace :bench do

  desc "Run a Benchmark report against the Benchmark server"
  task :report do |t, args|
    require 'bench/runner'
    Bench::Runner.new.build_report
  end

end
