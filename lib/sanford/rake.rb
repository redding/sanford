module Sanford::Rake

  class Tasks
    extend ::Rake::DSL

    def self.load
      namespace :sanford do

        # Overwrite this to load your application's environment so that it can
        # be used with Sanford
        task :setup

        task :load_manager => :setup do
          require 'sanford'
          Sanford.init
        end

        desc "Start a Sanford server and daemonize the process"
        task :start, [ :name, :port, :hostname ] => :load_manager do |t, args|
          Sanford::Manager.call(:start, args)
        end

        desc "Stop a daemonized Sanford server process"
        task :stop, [ :name, :port, :hostname ]  => :load_manager do |t, args|
          Sanford::Manager.call(:stop, args)
        end

        desc "Restart a daemonized Sanford server process"
        task :restart, [ :name, :port, :hostname ]  => :load_manager do |t, args|
          Sanford::Manager.call(:restart, args)
        end

        desc "Run a Sanford server (not daemonized)"
        task :run, [ :name, :port, :hostname ]  => :load_manager do |t, args|
          Sanford::Manager.call(:run, args)
        end

      end
    end

  end

end

Sanford::Rake::Tasks.load
