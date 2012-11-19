module TestHelper
  extend self

  def preserve_and_clear_hosts
    @previous_hosts = Sanford.config.hosts.dup
    Sanford.config.hosts.clear
  end

  def restore_hosts
    Sanford.config.hosts = @previous_hosts
    @previous_hosts = nil
  end

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
