require 'sanford/pid_file'

module Sanford

  class ProcessSignal

    attr_reader :signal, :pid

    def initialize(server, signal)
      @signal = signal
      @pid = PIDFile.new(server.pid_file).pid
    end

    def send
      ::Process.kill(@signal, @pid)
    end

  end

end
