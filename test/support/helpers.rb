module Test
  module SpawnServerHelper

    def start_server(host, &block)
      begin
        server = Sanford::ServerOld.new(host, { :ready_timeout => 0.1 })
        server.listen(host.ip, host.port)
        thread = server.start
        yield
      ensure
        server.halt if server
        thread.join if thread
      end
    end

  end
end
