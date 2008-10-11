module Testjour
  module CLI
    
    class HelpCommand < BaseCommand
      def self.command
        "help"
      end
      
      def run
        puts usage
        exit 1
      end
    end
    
  end
end