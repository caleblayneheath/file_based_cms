ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'history.txt'
  end

  def test_viewing_text_file
    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'Ruby'
  end

  def test_viewing_markdown_file
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_file_does_not_exist
    fake_file = 'nonononono.json'
    get "/#{fake_file}"

    assert_equal 302, last_response.status

    get last_response["location"]
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "#{fake_file} does not exist."

    get "/"
    refute_includes last_response.body, "#{fake_file} does not exist."
  end

end