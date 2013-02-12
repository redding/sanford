module Test

  module ForkServerHelper

    def start_server(host, &block)
      begin
        server = Sanford::Server.new(host, { :ready_timeout => 0.1 })
        thread = server.run(host.ip, host.port)
        yield
      ensure
        server.halt if server
        thread.join if thread
      end
    end

  end

  module ManagerHelper

    # start a Sanford server using Sanford's manager in a forked process
    def fork_and_call(proc, &block)
      pid = fork do
        STDOUT.reopen('/dev/null') unless ENV['SANFORD_DEBUG']
        manager = proc.call
        trap("TERM"){ manager.stop }
      end
      sleep 0.3 # give time for the command to run
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

  end

end
