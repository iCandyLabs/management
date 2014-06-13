require_relative '../../command'

module Management

  module Server

    class Console < Management::Command

      include Management::Helper

      def run()
        require 'pry'
        binding.pry
      end

    end

  end

end
