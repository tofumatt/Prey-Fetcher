ENV['RACK_ENV'] = 'test'

require File.join(File.dirname(__FILE__), '../', "prey_fetcher.rb")
require 'test/unit'
require 'rack/test'

class PreyFetcherTest < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def test_homepage_works_as_anonymous
    get '/'
    assert last_response.ok?
  end
  
  def test_account_fails_as_anonymous
    get '/account'
    assert !last_response.ok?
    put '/account'
    assert !last_response.ok?
    delete '/account'
    assert !last_response.ok?
    
    put '/lists'
    assert !last_response.ok?
  end
  
  def test_logout_works
    flunk 'Test is incomplete (requires sessions).'
    
    put '/login', {}, {:oauth_token => 'l9Ep677tgatsLlSc7PcJbMyXR41bVRwSTI1zLSrc', :oauth_verifier => '7T2JZoWeQCDAqiRnPCDuxki2LmsQAiUZ57bTSHaNbY'}
    
    assert session[:logged_in]
    
    get '/logout'
    follow_redirect!
    assert last_response.ok?
    assert !session[:logged_in]
  end
  
  def test_logout_fails_as_anonymous
    get '/logout'
    assert !last_response.ok?
  end
end
