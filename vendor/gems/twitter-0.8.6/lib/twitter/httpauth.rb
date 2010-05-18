module Twitter
  class HTTPAuth
    include HTTParty
    format :plain
    
    attr_reader :username, :password, :options
    
    def initialize(username, password, options={})
      @username, @password = username, password
      @options = {:ssl => false}.merge(options)
      options[:api_endpoint] ||= "twitter.com"
      self.class.base_uri "http#{'s' if options[:ssl]}://#{options[:api_endpoint]}"
    end
    
    def get(uri, headers={})
      self.class.get(uri, :headers => headers, :basic_auth => basic_auth)
    end
    
    def post(uri, body={}, headers={})
      self.class.post(uri, :body => body, :headers => headers, :basic_auth => basic_auth)
    end
    
    def put(uri, body={}, headers={})
      self.class.put(uri, :body => body, :headers => headers, :basic_auth => basic_auth)
    end
    
    def delete(uri, body={}, headers={})
      self.class.delete(uri, :body => body, :headers => headers, :basic_auth => basic_auth)
    end
    
    private
      def basic_auth
        @basic_auth ||= {:username => @username, :password => @password}
      end
  end
end