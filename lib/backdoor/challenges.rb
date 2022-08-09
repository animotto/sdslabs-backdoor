# frozen_string_literal: true

module Backdoor
  ##
  # Challenge
  class Challenge
    def initialize(shell)
      @shell = shell
    end

    def exist?(name)
      ChallengeBase.successors.any? { |s| s::NAME == name }
    end

    def run(name, args)
      challenge = ChallengeBase.successors.detect { |s| s::NAME == name }
      raise ArgumentError, 'No such challenge' unless challenge

      challenge.new(@shell, args[1..]).exec
    end
  end

  ##
  # ChallengeBase
  class ChallengeBase
    attr_reader :successors

    @successors = []

    class << self
      def inherited(subclass)
        super
        @successors << subclass
      end
    end

    def initialize(shell, args)
      @shell = shell
      @args = args
    end

    def exec; end

    def log(message)
      @shell.output.puts("[#{self.class::NAME}]: #{message}")
    end
  end
end
