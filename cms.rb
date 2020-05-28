require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

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

def valid_file_name?(filename)
  ['.txt', '.md'].include?(File.extname(filename))
end

def require_signed_in_user
  unless session[:username]
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
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

# requires signin
get '/new' do
  require_signed_in_user
  erb :new, layout: :layout
end

get '/:filename' do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{file_name} does not exist."
    redirect '/'
  end
end

# requires signin
get '/:filename/edit' do
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

post '/users/signin' do
  if params[:username] == 'admin' && params[:pwd] == 'secret'
    session[:username] = params[:username]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    status 422
    erb :signin, layout: :layout
  end
end

# requires signin
post '/create' do
  require_signed_in_user
  
  file_name = params[:filename]
  
  if valid_file_name?(file_name)
    file_path = File.join(data_path, file_name)
    File.write(file_path, '')
    session[:message] = "#{file_name} was created."
    redirect '/'
  else
    session[:message] = 'A valid name is required.'
    status 422
    erb :new, layout: :layout
  end
end

post '/users/signout' do
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end

# requires signin
post '/:filename' do
  require_signed_in_user
  
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  new_contents = params[:content]
  File.write(file_path, new_contents)

  session[:message] = "#{file_name} has been updated."
  redirect '/'
end

# requires signin
post '/:filename/delete' do
  require_signed_in_user
  
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  File.delete(file_path)

  session[:message] = "#{file_name} was deleted."
  redirect '/'
end