$LOAD_PATH << File.expand_path("#{File.dirname(__FILE__)}/../lib")
require 'fastprowl'

require 'rubygems'
require 'test/unit'
require 'mocha'

class FastProwlTest < Test::Unit::TestCase
  
  APPLICATION = 'FastProwl Unit Tests (http://github.com/tofumatt/FastProwl)'
  BAD_API_KEY = 'badapikeyftw'
  # This is a <b>valid API key</b> for an account with no devices. I'm not sure how
  # you'd go about abusing it, but please don't.
  VALID_API_KEY = 'c7634829dfafb02cc966df2f3dfc2c75fe2c9ef1'
  
  # Priority range is -2..2
  def test_invalid_priority
    assert_raises(FastProwl::PriorityOutOfRange) { FastProwl.add(:apikey => VALID_API_KEY, :priority => 10) }
  end
  
  # API key(s) are _required_
  def test_no_api_key
    assert_raises(FastProwl::MissingAPIKey) { FastProwl.add(:apikey => nil) }
  end
  
  # This key will fail
  def test_invalid_api_key
    assert !FastProwl.add(:apikey => BAD_API_KEY, :application => APPLICATION, :event => 'test_invalid_api_key', :description => "This shouldn't work.")
  end
  
  # Sending works
  def test_valid_api_key
    assert FastProwl.add(:apikey => VALID_API_KEY, :application => APPLICATION, :event => 'test_valid_api_key', :description => "This should work.")
  end
  
  # Test an invalid API key
  def test_invalid_api_key
    assert !FastProwl.verify(BAD_API_KEY)
  end
  
  # Verify an API key
  def test_verify_api_key
    assert FastProwl.verify(VALID_API_KEY)
  end
  
  # Concurrency test -- try to send a bunch of notifications
  def test_multi
    prowl = FastProwl.new
    
    10.times do
      prowl.add(:apikey => VALID_API_KEY, :application => APPLICATION, :event => 'test_multi', :description => "This is a concurrency test -- it should work.")
    end
    
    assert prowl.run
  end
  
  # Concurrency test -- try to send a bunch of notifications, including one with a bad API key
  def test_multi_onefails
    prowl = FastProwl.new
    
    prowl.add(:apikey => BAD_API_KEY, :application => APPLICATION, :event => 'test_multi_onefails', :description => "This is a concurrency test -- it should work, but one key is bad.")
    
    9.times do
      prowl.add(:apikey => VALID_API_KEY, :application => APPLICATION, :event => 'test_multi_onefails', :description => "This is a concurrency test -- it should work, but one key is bad.")
    end
    
    assert prowl.run
  end
  
  # Concurrency test -- try to send a bunch of notifications, all with a bad API keys
  def test_multi_allfail
    prowl = FastProwl.new
    
    10.times do
      prowl.add(:apikey => BAD_API_KEY, :application => APPLICATION, :event => 'test_multi_allfail', :description => "This is a concurrency test -- it shouldn't work.")
    end
    
    assert !prowl.run
  end
  
end