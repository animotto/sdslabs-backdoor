# frozen_string_literal: true

module Backdoor
  ##
  # Client HTTP
  class ClientHTTP
    def initialize
      @uri = URI(self.class::CLIENT_URI)
    end

    def get; end

    def post; end

    private

    def prepare_headers(headers, cookies)
      headers = headers.clone
      cookie = []
      cookies.each do |k, v|
        cookie << [
          URI.encode_www_form_component(k),
          URI.encode_www_form_component(v)
        ].join('=')
      end
      headers['Cookie'] = cookie.join('; ') unless cookie.empty?

      headers
    end
  end

  ##
  # Client web
  class ClientWeb < ClientHTTP
    CLIENT_URI = 'http://hack.bckdr.in'

    def initialize(port, ssl: false)
      super()
      @client = Net::HTTP.new(@uri.host, port)
      @client.use_ssl = ssl
    end

    def get(path, headers: {}, cookies: {})
      response = @client.get([@uri.path, path].join, prepare_headers(headers, cookies))
      raise HTTPError.new(response.code), response.code unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def post(path, data, headers: {}, cookies: {})
      response = @client.get([@uri.path, path].join, data, prepare_headers(headers, cookies))
      raise HTTPError.new(response.code), response.code unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end

  ##
  # Client static
  class ClientStatic < ClientHTTP
    CLIENT_URI = 'http://static.beast.sdslabs.co/static'

    def initialize
      super
      @client = Net::HTTP.new(@uri.host, @uri.port)
      @client.use_ssl = @uri.instance_of?(URI::HTTPS)
    end

    def get(path)
      response = @client.get([@uri.path, path].join)
      raise HTTPError.new(response.code), response.code unless response.is_a?(Net::HTTPSuccess)

      response.body
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
