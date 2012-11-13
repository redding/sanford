Bundler.setup(:benchmark)
require 'benchmark'
require 'whysoslow'

require 'bench/client'

module Bench

  class Runner
    # this should match up with bench/services host and port
    HOST_AND_PORT = [ '127.0.0.1', 12000 ]

    REQUESTS = [
      [ 'simple', 'v1', {}, 10000 ],
      # [ 'v1/memory_check', {}, 10000 ] # TODO - check the server's memory with whysoslow
                                         # probably need a special method to collect the info
                                         # from the server, need to be able to configure
                                         # services before I can do this
    ]

    TIME_MODIFIER = 10 ** 4 # 4 decimal places

    def initialize(options = {})
      options[:output] ||= File.expand_path("../report.txt", __FILE__)

      @file = File.open(options[:output], "w")
    end

    def build_report
      output "Running benchmark report..."

      REQUESTS.each do |name, version, params, times|
        self.benchmark_service(name, version, params, times, false)
      end

      output "Done running benchmark report"
    end

    def benchmark_service(name, version, params, times, show_result = false)
      benchmarks = []

      output "\nHitting #{name.inspect} service with #{params.inspect}, #{times} times"
      [*(1..times.to_i)].each do |index|
        benchmark = self.hit_service(name, version, params.merge({ :request_number => index }), show_result)
        benchmarks << self.round_time(benchmark.real * 1000.to_f)
        output('.', false) if ((index - 1) % 100 == 0) && !show_result
      end
      output("\n", false)

      total_time = benchmarks.inject(0){|s, n| s + n }
      data = {
        :number_of_requests => times,
        :total_time_taken   => self.round_and_display(total_time),
        :average_time_taken => self.round_and_display(total_time / benchmarks.size),
        :min_time_taken     => self.round_and_display(benchmarks.min),
        :max_time_taken     => self.round_and_display(benchmarks.max)
      }
      size = data.values.map(&:size).max
      output "Total Time:   #{data[:total_time_taken].rjust(size)}ms"
      output "Average Time: #{data[:average_time_taken].rjust(size)}ms"
      output "Min Time:     #{data[:min_time_taken].rjust(size)}ms"
      output "Max Time:     #{data[:max_time_taken].rjust(size)}ms"
      output "\n"
    end

    protected

    def hit_service(name, version, params, show_result)
      Benchmark.measure do
        begin
          client = Bench::Client.new(*HOST_AND_PORT)
          response = client.call(name, version, params)
          if show_result
            output "Got a response:"
            output "  #{response.status}"
            output "  #{response.result.inspect}"
          end
        rescue Exception => exception
          puts "FAILED -> #{exception.class}: #{exception.message}"
          puts exception.backtrace.join("\n")
        end
      end
    end

    def output(message, puts = true)
      method = puts ? :puts : :print
      self.send(method, message)
      @file.send(method, message)
      STDOUT.flush if method == :print
    end

    def round_and_display(time_in_ms)
      self.display_time(self.round_time(time_in_ms))
    end

    def round_time(time_in_ms)
      (time_in_ms * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
    end

    def display_time(time)
      integer, fractional = time.to_s.split('.')
      [ integer, fractional.ljust(4, '0') ].join('.')
    end

  end

end
