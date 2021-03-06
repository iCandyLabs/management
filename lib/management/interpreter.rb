module Management

  def self.interpret!(argv)
    require 'optparse'

    commands = Management::Command.all

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: management [command [arg ...]]"
      opts.separator('')
      opts.separator('Commands:')
      commands.each { |command| opts.separator command.help_string }
      opts.separator('')
      opts.on('-h', '--help', 'Display this screen') { abort opts.to_s }
      opts.on('-v', '--version', 'Show version') { abort Management::VERSION }
    end

    abort parser.help if argv.empty?
    error_handler = lambda { |e| abort "Error: #{e}\n\n" + parser.help }

    args = parser.parse(argv)
    task = args.shift

    command = commands.find{|c|c.command_name == task}
    error_handler.call "unknown task \"#{task}\"" if command.nil?

    command.call_with(args, error_handler)
  end

end
