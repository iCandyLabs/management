require_relative '../command'

module Management

  class OpenConsole < Management::Command

    include Management::Helper

    def run()
      require 'pry'
      binding.pry
    end

  end

end
