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

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
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

  def test_viewing_text_document
    create_document 'changes.txt', 'Ruby'

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'Ruby'
  end

  def test_viewing_markdown_document
    create_document 'about.md', '#Ruby is...'
    
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_document_not_found
    fake_file = 'nonononono.json'
    get "/#{fake_file}"

    assert_equal 302, last_response.status
    assert_equal "#{fake_file} does not exist.", session[:message]
  end

  def test_editing_document
    create_document 'history.txt'
    get '/history.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, "<input type='submit'"
  end

  def test_updating_document
    # get '/', {}, admin_session
    post '/changes.txt', { content: 'new Ruby content' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been updated.', session[:message]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new Ruby content'
  end

  def test_view_new_document_form
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input type='submit'"
  end

  def test_create_new_document
    post '/create', { filename: 'test.txt' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test.txt was created.', session[:message]

    get '/'
    assert_includes last_response.body, 'test.txt'
  end

  def test_create_new_document_without_filename
    post '/create', { filename: '' }, admin_session
    assert_equal 422, last_response.status
    
    assert_includes last_response.body, 'A valid name is required.'
  end

  def test_create_new_document_without_valid_extension
    post '/create', { filename: 'anything.json' }, admin_session
    assert_equal 422, last_response.status
    
    assert_includes last_response.body, 'A valid name is required.'
  end

  def test_deleting_document
    create_document 'test.txt'
    post '/test.txt/delete', {}, admin_session

    assert_equal 302, last_response.status
    
    assert_equal 'test.txt was deleted.', session[:message]
    get last_response['Location']

    get '/'
    refute_includes last_response.body, 'href="/test.txt"'
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input type='submit'"
  end

  def test_signin
    post '/users/signin', username: 'admin', pwd: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin.'
  end

  def test_signin_with_bad_credentials
    post '/users/signin', username: 'guest', pwd: 'wrong'
    assert_equal 422, last_response.status
    
    assert_nil session[:username]
    assert_includes last_response.body, 'Invalid Credentials'
  end

  def test_signout
    get '/', {}, admin_session
    assert_includes last_response.body, "Signed in as admin."
    
    post '/users/signout'
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:username]
    assert_includes last_response.body, 'Sign In'
  end
  
  def test_view_edit_document_signedout
  
  end

  def test_update_document_signedout

  end
  
  def test_deleting_document_signedout
  
  end

  def test_view_new_document_form_signedout
  
  end

  def test_create_new_document_signedout
  
  end
end