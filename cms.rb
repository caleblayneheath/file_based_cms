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
      render_markdown(content)
    end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

get '/:filename' do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    if file_name != 'favicon.ico'
      session[:message] = "#{file_name} does not exist."
    end
    redirect '/'
  end
end

get '/:filename/edit' do
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

post '/:filename' do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  new_contents = params[:content]
  File.write(file_path, new_contents)

  session[:message] = "#{file_name} has been updated."
  redirect '/'
end