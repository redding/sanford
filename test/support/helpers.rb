module Test

  module Environment

    def self.store_and_clear_hosts
      @previous_hosts = Sanford.hosts.instance_variable_get("@set").dup
      Sanford.hosts.clear
    end

    def self.restore_hosts
      Sanford.instance_variable_set("@hosts", Sanford::Hosts.new(@previous_hosts))
      @previous_hosts = nil
    end

  end

  module ForkServerHelper

    def start_server(server, &block)
      begin
        pid = fork do
          trap("TERM"){ server.stop }
          server.start
          server.join_thread
        end
        sleep 0.3 # Give time for the socket to start listening.
        yield
      ensure
        if pid
          Process.kill("TERM", pid)
          Process.wait(pid)
        end
      end
    end

  end

  module ForkManagerHelper

    # start a Sanford server using Sanford's manager in a forked process
    def call_sanford_manager(*args, &block)
      pid = fork do
        STDOUT.reopen('/dev/null') unless ENV['SANFORD_DEBUG']
        trap("TERM"){ exit }
        Sanford::Manager.call(*args)
      end
      sleep 1.5 # give time for the command to run
      yield
    ensure
      if pid
        Process.kill("TERM", pid)
        Process.wait(pid)
      end
    end

    def open_socket(host, port)
      socket = TCPSocket.new(host, port)
    ensure
      socket.close rescue false
    end

    def expected_pid_file(host, ip, port)
      host.pid_dir.join("#{ip}_#{port}_#{host}.pid")
    end

  end

end
