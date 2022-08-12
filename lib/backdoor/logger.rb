# frozen_string_literal: true

module Backdoor
  ##
  # Logger
  class Logger
    def initialize(output, prefix)
      @output = output
      @prefix = prefix
    end

    def puts(message)
      @output.puts("[#{@prefix}]: #{message}")
    end
  end
end
