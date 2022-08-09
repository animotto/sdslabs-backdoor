# frozen_string_literal: true

require 'readline'
require 'shellwords'

module Backdoor
  ##
  # Shell
  class Shell
    attr_reader :input, :output

    PROMPT = 'backdoor> '
    COMMANDS = {
      quit: %w[quit],
      help: %w[help ?],
      challenge: %w[challenge]
    }.freeze

    def initialize(input = $stdin, output = $stdout)
      @input = input
      @output = output
      @running = false
      @commands = COMMANDS.values.flatten
      @challenge = Challenge.new(self)
    end

    def run
      Readline.completion_proc = proc do |line|
        @commands.grep(/^#{Regexp.escape(line)}/)
      end

      @running = true
      loop do
        break unless @running

        line = Readline.readline(PROMPT, true)
        unless line
          @output.puts
          break
        end

        line.strip!
        tokens = Shellwords.split(line)
        if tokens.empty?
          Readline::HISTORY.pop
          next
        end

        command = tokens.first.downcase
        command = COMMANDS.detect { |_, v| v.include?(command) }
        unless command
          @output.puts('Unrecognized command')
          next
        end

        method = ['cmd_', command.first].join.to_sym
        send(method, tokens[1..])
      rescue Interrupt
        @output.puts
        next
      end
    end

    private

    def cmd_quit(_args)
      @running = false
    end

    def cmd_help(_args)
      @output.puts('Commands: ')
      COMMANDS.sort.each do |command|
        @output.puts(" #{command.first}")
      end
    end

    def cmd_challenge(args)
      name = args.first
      unless @challenge.exist?(name)
        @output.puts('No such challenge')
        return
      end

      @challenge.run(name, args[1..])
    end
  end
end
