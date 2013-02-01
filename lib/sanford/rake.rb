module Sanford::Rake

  class Tasks
    extend ::Rake::DSL

    def self.load
      namespace :sanford do

        task :load_manager do
          require 'sanford'
          require 'sanford/manager'
          Sanford.init
        end

        desc "(sanford) Start a Sanford server and daemonize the process"
        task :start => :load_manager do
          Sanford::Manager.call :start
        end

        desc "(sanford) Stop a daemonized Sanford server process"
        task :stop => :load_manager do
          Sanford::Manager.call :stop
        end

        desc "(sanford) Restart a daemonized Sanford server process"
        task :restart => :load_manager do
          Sanford::Manager.call :restart
        end

        desc "(sanford) Run a Sanford server (not daemonized)"
        task :run => :load_manager do
          Sanford::Manager.call :run
        end

      end
    end

  end

end

Sanford::Rake::Tasks.load
