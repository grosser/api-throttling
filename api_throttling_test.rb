require 'rubygems'
require 'rack/test'
require 'test/unit'
require 'api_throttling'
require 'redis'

#  To Run this test, you need to have the redis-server running.
#  And you need to have rack-test gem installed: sudo gem install rack-test
#  For more information on rack-test, visit: http://github.com/brynary/rack-test

class ApiThrottlingTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    app = Rack::Builder.new {
      use ApiThrottling, :requests_per_hour => 3
      run lambda {|env| [200, {'Content-Type' =>  'text/plain', 'Content-Length' => '12'}, ["Hello World!"] ] }
    }
  end
  
  def setup
    # Delete all the keys for 'joe' in Redis so that every test starts fresh
    r = Redis.new
    r.keys("joe*").each do |key|
      r.delete key
    end
  end
  
  def test_first_request_should_return_hello_world
    authorize "joe", "secret"
    get '/'
    assert_equal 200, last_response.status
    assert_equal "Hello World!", last_response.body    
  end
  
  def test_fourth_request_should_be_blocked
    authorize "joe", "secret"
    get '/'
    assert_equal 200, last_response.status
    get '/'
    assert_equal 200, last_response.status
    get '/'
    assert_equal 200, last_response.status
    get '/'
    assert_equal 503, last_response.status
    get '/'
    assert_equal 503, last_response.status
  end
  
  def test_over_rate_limit_should_only_apply_to_user_that_went_over_the_limit
    authorize "joe", "secret" 
    get '/'
    get '/'
    get '/'
    get '/'
    get '/'
    assert_equal 503, last_response.status
    authorize "luc", "secret"
    get '/'
    assert_equal 200, last_response.status
  end
  
end