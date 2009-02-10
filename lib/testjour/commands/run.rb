require "optparse"

require "testjour/commands/command"
require "testjour/http_queue"
require "testjour/cucumber_extensions/step_counter"
require "testjour/results_formatter"

module Testjour
module Commands
    
  class Run < Command
    
    def execute
      @max_local_slaves = 2
      parse_options
      
      HttpQueue.with_queue_server do
        queue_features
        start_slaves
        print_results
      end
    end
    
    def cucumber_options
    end
    
    def parse_options
      @unknown_args = []
      
      Testjour.logger.info "Parsing options: #{@args.inspect}"
      
      begin
        option_parser.parse!(@args)
      rescue OptionParser::InvalidOption => e
        e.recover @args
        
        @unknown_args << @args.shift
        
        if @args.any? && @args.first[0..0] != "-"
          @unknown_args << @args.shift
        end
        
        retry
      end
    end
    
    def queue_features
      require 'cucumber/cli/main'
      cucumber_configuration.load_language
      
      HttpQueue.with_queue(queue_uri) do |queue|
        cucumber_configuration.feature_files.each do |feature_file|
          queue.push(:feature_files, feature_file)
        end
      end
    end
    
    def start_slaves
      local_slave_count.times do
        start_slave
      end
    end
    
    def start_slave
      Testjour.logger.info "Starting slave: #{local_run_command}"
      detached_exec(local_run_command)
    end
    
    def print_results
      results_formatter = ResultsFormatter.new(step_count)
      
      HttpQueue.with_queue(queue_uri) do |queue|
        step_count.times do
          result = queue.pop(:results)
          results_formatter.result(*result)
        end
      end
      
      results_formatter.finish
      
      return results_formatter.failed? ? 1 : 0
    end
    
    def count_steps(feature_files)
      features = load_plain_text_features(feature_files)
      visitor = Testjour::StepCounter.new(step_mother)
      visitor.visit_features(features)
      return visitor.count
    end
    
    def step_count
      @step_count ||= count_steps(cucumber_configuration.feature_files)
    end
    
    def local_slave_count
      [feature_files_count, @max_local_slaves].min
    end
    
    def feature_files_count
      cucumber_configuration.feature_files.size
    end
    
    def local_run_command
      "testjour run:slave #{[args_from_options + @unknown_args].join(' ')} #{testjour_uri}".squeeze(" ")
    end
    
    def args_from_options
      args_from_options = []
      if @options[:create_mysql_db]
        args_from_options << "--create-mysql-db"
      end
      return args_from_options
    end
    
    def queue_uri
      "http://localhost:#{Testjour::HttpQueue.port}/"
    end
    
    def testjour_uri
      "http://localhost:#{Testjour::HttpQueue.port}" + File.expand_path(".")
    end
    
    def testjour_path
      File.expand_path(File.dirname(__FILE__) + "/../../../bin/testjour")
    end
    
  end
  
end
end