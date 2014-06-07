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

        abort parser.help if input.empty?

        args = parser.parse(input)
        task = args.shift
        ARGV.clear

        if chosen_command = commands.find{|c|c.command_name == task}
          all_args = chosen_command.instance_method(:call).parameters
          req_args = all_args.map(&:first).take_while{|p| p == :req}

          case args.count
          when args.count < req_args.count
            puts "Error: not enough arguments"
            abort parser.help
          when args.count > all_args.count
            puts "Error: too many arguments"
            abort parser.help
          else
            chosen_command.new.call(*args)
          end
        else
          puts "Error: unknown task \"#{task}\""
          abort parser.help
        end
      end

    end

  end

end
