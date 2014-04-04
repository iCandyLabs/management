require 'optparse'

module Billow

  class Interpreter

    class << self

      def interpret!(input)
        commands = Billow::Command.all

        parser = OptionParser.new do |opts|
          opts.banner = "Usage:"
          opts.separator('')
          commands.each { |cmd| opts.separator cmd.help_string }
          opts.separator('')
          opts.on('-h', '--help', 'Display this screen') { puts opts; exit }
          opts.on('-v', '--version', 'Show version') { puts Billow::VERSION; exit }
        end

        input << "-h" if input.empty?
        args = parser.parse(input)
        task = args.shift

        if chosen_command = commands.find{|c|c.command_name == task}
          chosen_command.new.call(*args)
        else
          puts "Error: unknown task \"#{task}\""
        end
      end

    end

  end

end
