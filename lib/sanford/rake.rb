module Sanford::Rake

  class Tasks
    extend ::Rake::DSL

    def self.load
      namespace :sanford do

        task :load_manager do
          require 'sanford'
          Sanford::Manager.load_configuration
        end

        desc "Start a Sanford server and daemonize the process"
        task :start, [ :name ] => :load_manager do |t, args|
          Sanford::Manager.call(args[:name], :start)
        end

        desc "Stop a daemonized Sanford server process"
        task :stop, [ :name ]  => :load_manager do |t, args|
          Sanford::Manager.call(args[:name], :stop)
        end

        desc "Restart a daemonized Sanford server process"
        task :restart, [ :name ]  => :load_manager do |t, args|
          Sanford::Manager.call(args[:name], :restart)
        end

        desc "Run a Sanford server (not daemonized)"
        task :run, [ :name ]  => :load_manager do |t, args|
          Sanford::Manager.call(args[:name], :run)
        end

      end
    end

  end

end

Sanford::Rake::Tasks.load
