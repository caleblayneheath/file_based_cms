require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

#[x] Validate that document names contain an extension that the application supports.
#[x] Add a "duplicate" button that creates a new document based on an old one.
#[x] Extend this project with a user signup form.
#[ ] Add the ability to upload images to the CMS (which could be referenced within markdown files).
#[ ] Modify the CMS so that each version of a document is preserved as changes are made to it.
=begin
when editing file
  parse into three parts
    name, version(optional), extension
  increment version
  combine parts into new version file name
=end

configure do
  enable :sessions
  set :session_secret, 'codfish'
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
    content = File.read(path)
    case File.extname(path)
    when '.txt'
      headers['Content-Type'] = "text/plain"
      content
    when '.md'
      erb render_markdown(content)
    end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credential_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def load_user_credentials
  YAML.load_file(credential_path)
end

def valid_login?(username, password)
  credentials = load_user_credentials
  if credentials.key?(username)
    BCrypt::Password.new(credentials[username]) == password
  else
    false
  end
end

def valid_file_name?(filename)
  ['.txt', '.md'].include?(File.extname(filename))
end

def require_signed_in_user
  unless session[:username]
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
  end
end


def signup_error(username, password)
  credentials = load_user_credentials

  if username == ''
    'No username entered.'
  elsif credentials[username]
    "The user #{username} already exists."
  elsif password.size < 6
    'Password must be at least 6 characters long.'
  end
end

def add_user_credentials(username, password)
  credentials = load_user_credentials
  credentials[username] = BCrypt::Password.create(password).to_s
  File.open(credential_path, 'w') do |file|
    file.write(credentials.to_yaml)
  end
end

get '/' do 
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

get '/users/signin' do
  erb :signin, layout: :layout
end

get '/users/new' do 
  erb :signup, layout: :layout
end

# requires signin
get '/new' do
  require_signed_in_user
  erb :new, layout: :layout
end

get '/view/:filename' do
  # File.basename is security feature, strips out all but file and extension
  file_name = File.basename(params[:filename])
  file_path = File.join(data_path, file_name)
  
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{file_name} does not exist."
    redirect '/'
  end
end

# requires signin
get '/edit/:filename' do
  require_signed_in_user
  
  @file_name = params[:filename]
  file_path = File.join(data_path, @file_name)

  @content = File.read(file_path) if File.exist?(file_path)

  if @content
    erb :edit, layout: :layout
  else
    session[:message] = "#{@file_name} does not exist."
    redirect '/'
  end
end

get '/duplicate/:filename' do
  require_signed_in_user
  @file_name = params[:filename]
  erb :duplicate, layout: :layout
end

post '/duplicate/:filename' do
  require_signed_in_user
  @file_name = params[:filename]
  duplicate_filename = params[:dupname]

  error = file_name_error(duplicate_filename)

  if error
    session[:message] = error
    status 422
    erb :duplicate, layout: :layout
  else
    duplicate_file_path = File.join(data_path, duplicate_filename)
    original_file_path = File.join(data_path, @file_name)
    
    File.write(duplicate_file_path, File.read(original_file_path))
    session[:message] = "#{duplicate_filename} duplicated from #{@file_name}"
    redirect '/'
  end
end

post '/users/signin' do
  username = params[:username]
  password = params[:pwd]
  if valid_login?(username, password)
    session[:username] = params[:username]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    status 422
    erb :signin, layout: :layout
  end
end

def file_name_error(file_name)
  if !valid_file_name?(file_name)
    'A valid name is required.'
  elsif File.exist?(File.join(data_path, file_name))
    "#{file_name} already exists."
  end
end

# requires signin
post '/create' do
  require_signed_in_user
  
  file_name = params[:filename]
  error = file_name_error(file_name)

  if error
    session[:message] = error
    status 422
    erb :new, layout: :layout
  else
    file_path = File.join(data_path, file_name)
    File.write(file_path, '')
    session[:message] = "#{file_name} was created."
    redirect '/'
  end
end

post '/users/signout' do
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end

post '/users/new' do
  username = params[:username]
  password = params[:password]

  error = signup_error(username, password)
  if error 
    session[:message] = error
    status 422
    erb :signup, layout: :layout
  else
    add_user_credentials(username, password)
    session[:message] = "User #{username} added."
    redirect '/'
  end
end

# requires signin
post '/update/:filename' do
  require_signed_in_user
  
  filename = params[:filename]
  # old_file_name = params[:filename]
  # new_file_name = old_file_name + "_v#{Time.new.to_i}"
  file_path = File.join(data_path, filename)

  new_contents = params[:content]
  File.write(file_path, new_contents)

  session[:message] = "#{filename} has been updated."
  redirect '/'
end

# requires signin
post '/delete/:filename' do
  require_signed_in_user
  
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  File.delete(file_path)

  session[:message] = "#{file_name} was deleted."
  redirect '/'
end