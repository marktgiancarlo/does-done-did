require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
# allows us to render an eRB template form somewhere within the Sinatra app

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def all_completed?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def num_completed_todos(list)
    list[:todos].count { |todo| todo[:completed] }
  end

  def list_class(list)
    'complete' if all_completed?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| all_completed?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo|todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET  /lists     -> view all lists
# GET  /lists/new -> new list form
# POST /list      -> create new list
# GET  /lists/1   -> view a single list

# view all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end


get '/lists/:id' do
  @id = params[:id].to_i
  @list = session[:lists][@id]

  erb :todos, layout: :layout
end

# edit an existing list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]

  erb :edit_list, layout: :layout
end

# return an error message if the name is invalid. return nil if name is valid.
def error_for_name_input(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo_input(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  end
end

def assign_id
  if session[:lists].empty?
    0
  else
    session[:lists].each_with_object([]) do |list, obj|
      obj << list[:id]
    end.max + 1
  end
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_name_input(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

post "/lists/#{@id}" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_name_input(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][id][:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{@id}"
  end
end

# delete a todo list
post '/lists/:id/delete' do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# add a todo to a list
post '/lists/:id/todos' do
  todo = params[:todo].strip
  @id = params[:id].to_i
  @list = session[:lists][@id]

  error = error_for_todo_input(todo)
  if error
    session[:error] = error
    erb :todos, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@id}"
  end
end

# delete a todo from a list
post '/lists/:id/todos/:index/delete' do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  @list[:todos].delete_at(params[:index].to_i)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@id}"
end

# update the completed status of a todo item
post '/lists/:id/todos/:index' do
  @id = params[:id].to_i
  @list = session[:lists][@id]

  is_completed = params[:completed] == 'true'
  @list[:todos][params[:index].to_i][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@id}"
end

# update the completed status of all todo items in a list
post '/lists/:id/complete_all' do
  @id = params[:id].to_i
  @list = session[:lists][@id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@id}"
end