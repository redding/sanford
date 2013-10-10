Bundler.setup(:benchmark)
require 'benchmark'

require 'bench/client'

module Bench

  class Runner
    # this should match up with bench/services host and port
    HOST_AND_PORT = [ '127.0.0.1', 59284 ]

    REQUESTS = [
      [ 'simple', {}, 10000 ]
    ]

    TIME_MODIFIER = 10 ** 4 # 4 decimal places

    def initialize(options = {})
      options[:output] ||= File.expand_path("../report.txt", __FILE__)

      @file = File.open(options[:output], "w")
    end

    def build_report
      output "Running benchmark report..."

      REQUESTS.each do |name, params, times|
        self.benchmark_service(name, params, times, false)
      end

      output "Done running benchmark report"
    end

    def benchmark_service(name, params, times, show_result = false)
      benchmarks = []

      output "\nHitting #{name.inspect} service with #{params.inspect}, #{times} times"
      [*(1..times.to_i)].each do |index|
        benchmark = self.hit_service(name, params.merge({ :request_number => index }), show_result)
        benchmarks << self.round_time(benchmark.real * 1000.to_f)
        output('.', false) if ((index - 1) % 100 == 0) && !show_result
      end
      output("\n", false)

      total_time = benchmarks.inject(0){|s, n| s + n }
      average = total_time / benchmarks.size
      data = {
        :number_of_requests => times,
        :total_time_taken   => self.round_and_display(total_time),
        :average_time_taken => self.round_and_display(average),
        :min_time_taken     => self.round_and_display(benchmarks.min),
        :max_time_taken     => self.round_and_display(benchmarks.max)
      }
      size = data.values.map(&:size).max
      output "Total Time:   #{data[:total_time_taken].rjust(size)}ms"
      output "Average Time: #{data[:average_time_taken].rjust(size)}ms"
      output "Min Time:     #{data[:min_time_taken].rjust(size)}ms"
      output "Max Time:     #{data[:max_time_taken].rjust(size)}ms"

      output "\n"

      distribution = Distribution.new(benchmarks)

      output "Distribution (number of requests):"
      distribution.each do |grouping|
        output "  #{grouping.time}ms: #{grouping.number_of_requests}"
        grouping.precise_groupings.each do |precise_grouping|
          output "    #{precise_grouping.time}ms: #{precise_grouping.number_of_requests}"
        end
      end

      output "\n"
    end


    def hit_service(name, params, show_result)
      Benchmark.measure do
        begin
          client = Bench::Client.new(*HOST_AND_PORT)
          response = client.call(name, params)
          if show_result
            output "Got a response:"
            output "  #{response.status}"
            output "  #{response.data.inspect}"
          end
        rescue Exception => exception
          puts "FAILED -> #{exception.class}: #{exception.message}"
          puts exception.backtrace.join("\n")
        end
      end
    end

    protected

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

    class Distribution

      def initialize(benchmarks)
        hash = benchmarks.inject({}) do |hash, benchmark|
          index = Index.new(benchmark).number
          hash[index] ||= Grouping.new(index)
          hash[index].add(benchmark)
          hash
        end
        @groupings = hash.values.sort
      end

      def each(&block)
        @groupings.each(&block)
      end

      class BaseGrouping

        def self.max_time(time = nil)
          size = time.to_s.size
          @max_time = size if size > @max_time.to_i
          @max_time
        end

        def self.max_number(number = nil)
          size = number.to_s.size
          @max_size = size if size > @max_size.to_i
          @max_size
        end

        attr_reader :name

        def initialize(index)
          @name = index.to_s
          @set  = []
          self.class.max_time(index.to_s.size)
        end

        def add(benchmark)
          result = @set.push(benchmark)
          self.class.max_number(@set.size.to_s.size)
          result
        end

        def time
          @name.rjust(self.class.max_time)
        end

        def number_of_requests
          @set.size.to_s.rjust(self.class.max_number)
        end

        def <=>(other)
          self.name.to_f <=> other.name.to_f
        end

      end

      class Grouping < BaseGrouping

        def initialize(index)
          super
          @precise_groupings = {}
        end

        def add(benchmark)
          add_precise_grouping(benchmark) if self.collect_precise?
          super(benchmark)
        end

        def collect_precise?
          @name.to_i <= 1
        end

        def precise_groupings
          @precise_groupings.values.sort
        end

        protected

        def add_precise_grouping(benchmark)
          index = PreciseIndex.new(benchmark).number
          @precise_groupings[index] ||= BaseGrouping.new(index)
          @precise_groupings[index].add(benchmark)
        end

      end

      class Index < Struct.new(:number)

        def initialize(benchmark)
          super benchmark.to_i
        end
      end

      class PreciseIndex < Struct.new(:number)

        MODIFIER = 10.to_f

        def initialize(benchmark)
          super((benchmark * MODIFIER).to_i / MODIFIER)
        end

      end

    end

  end

end
