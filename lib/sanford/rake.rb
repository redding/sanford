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
          require 'sanford/manager'
          Sanford.init
        end

        desc "Start a Sanford server and daemonize the process"
        task :start => :load_manager do
          Sanford::Manager.call :start
        end

        desc "Stop a daemonized Sanford server process"
        task :stop => :load_manager do
          Sanford::Manager.call :stop
        end

        desc "Restart a daemonized Sanford server process"
        task :restart => :load_manager do
          Sanford::Manager.call :restart
        end

        desc "Run a Sanford server (not daemonized)"
        task :run => :load_manager do
          Sanford::Manager.call :run
        end

      end
    end

  end

end

Sanford::Rake::Tasks.load
