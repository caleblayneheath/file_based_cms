ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils' # for setting up and tearing down test files

require_relative '../cms'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'
    
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_text_file
    create_document 'changes.txt', 'Ruby'

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'Ruby'
  end

  def test_viewing_markdown_file
    create_document 'about.md', '#Ruby is...'
    
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

  def test_edit_file
    create_document 'history.txt'
    get '/history.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, "<input type='submit'"
  end

  def test_updating_file   
    post '/changes.txt', content: 'new Ruby content'

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new Ruby content'

  end
end