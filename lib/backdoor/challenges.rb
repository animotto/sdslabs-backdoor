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
    end
  end

  ##
  # ChallengeBase
  class ChallengeBase
    STATIC_URI = 'http://static.beast.sdslabs.co/static'

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

      @uri_static = URI(STATIC_URI)
      @client_static = Net::HTTP.new(@uri_static.host, @uri_static.port)
      @client_static.use_ssl = @uri_static.instance_of?(URI::HTTPS)
    end

    def exec; end

    def found(message)
      log("Found: #{message}")
    end

    def not_found
      log('Not found')
    end

    def log(message)
      @shell.output.puts("[#{self.class::NAME}]: #{message}")
    end

    def get_static(path)
      response = @client_static.get([@uri_static.path, path].join)
      raise HTTPError.new(response.code), response.code unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end

  ##
  # Challenge 2013-bin-50
  class Challenge2013bin50 < ChallengeBase
    NAME = '2013-bin-50'

    FILE = '/2013-BIN-50/binary50.zip'
    OFFSET = 0x87e

    def exec
      log("Downloading #{FILE}")
      file = get_static(FILE)

      zip_stream = Zip::InputStream.new(StringIO.new(file))
      entry = zip_stream.get_next_entry
      log("Unzipping #{entry}")

      log("Reading MD5 hash from offset 0x#{OFFSET.to_s(16)}")
      hash = String.new
      entry = StringIO.new(entry.get_input_stream.read)
      entry.seek(OFFSET)
      8.times do
        data = entry.read(7)
        hash << data[0..3]
      end

      log("Calculating SHA256 hash from MD5 hash #{hash}")
      hash = Digest::SHA256.hexdigest(hash)
      found(hash)
    rescue HTTPError => e
      log(e)
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
      log("Getting encrypted text #{FILE}")
      data = get_static(FILE)
      match = %r{<div>\s+(.+)\s+</div>}.match(data)
      data = match[1].clone
      log(data)

      log('Searching offsets')
      offsets = []
      TEXT.chars.each_with_index do |char, i|
        next unless ALPHABET.include?(char)

        a = ALPHABET.index(data[i])
        b = ALPHABET.index(char)
        n = a - b
        break if offsets.first == n

        offsets << n
      end
      log("Offsets: #{offsets}")

      log('Decrypting text')
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
  # HTTP error
  class HTTPError < StandardError
    def initialize(code)
      super
      @code = code
    end

    def to_s
      "HTTP error #{@code}"
    end
  end
end
