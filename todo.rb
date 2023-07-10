require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, "79deb0c636d0adf62237c14c2747fb1a8029ab99ed4e9a5555468448b588578f"
end

#Sets the error message if input does not pass validation. Returns a string or nil.
def error_for_list(name)
  if session[:lists].any? { |list| list.value?(name) }
    session[:error] = "Please enter a unique list name."
  elsif !(1..100).cover?(name.size)
    session[:error] = "Please enter a name between 1 and 100 characters."
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    session[:error] = "Please enter a name between 1 and 100 characters."
  end
end

def complete_all(todos)
  todos.each { |todo| todo[:completed] = true }
end

#sets the first element id (list or todo item) to 1 and the rest are incremented from the last
def next_id(array)
  max = array.map { |elem| elem[:id] }.max || 0
  max + 1
end

#returns the todo item with the given id
def select_todo(todos, todo_id)
  todos.find { |todo| todo[:id] == todo_id }
end

#tests the validity of the requested list and displays an error message if invalid
def list_valid?(list_id)
  list = session[:lists].find { |list| list[:id] == list_id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

helpers do
  #returns true if there's at least one todo and 0 with completed=false
  def list_complete?(list)
    todos_total(list[:todos]) > 0 && todos_remaining(list[:todos]) == 0
  end

  #returns string "complete" if all todos in list are marked completed=true
  def list_class(list)
    "complete" if list_complete?(list)
  end

  #returns the number of todos with completed=false
  def todos_remaining(todos) 
    todos.select { |todo| todo[:completed] == false }.count
  end

  #returns the total number of todo items
  def todos_total(todos)
    todos.count
  end

  #sorts lists by whether or not they are complete. completed lists go last
  def sort_lists(lists)
    lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
  end

  #sorts todos by whether or not they are complete. completed todos go last
  def sort_todos(todos)
    todos.sort_by { |todo| todo[:completed] == true ? 1 : 0 }
  end
end

before do
  session[:lists] ||= []
end

#redirects to list of lists
get "/" do
  redirect "/lists"
end

#displays list of lists
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

#adds new list to session[:lists] and redirects to list of lists
post "/lists" do
  list_name = params[:list_name].strip

  if error_for_list(list_name)
    erb :new_list, layout: :layout
  else
    id = next_id(session[:lists])
    session[:success] = "The list has been added successfully."
    session[:lists] << { name: list_name, id: id, todos: [] }
    redirect "/lists"
  end
end

#create a new list
get "/lists/new" do
  erb :new_list, layout: :layout
end

#displays a single list and its items
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = list_valid?(@list_id)
  @todos = @list[:todos]
  erb :list
end

#Edit a list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = list_valid?(@list_id)

  erb :edit_list, layout: :layout
end

#updates a list
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  list_name = params[:list_name].strip
  @list = list_valid?(@list_id)

  if error_for_list(list_name)
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated"
    redirect "/lists/#{@list_id}"
  end
end

#delete a list
post "/lists/:list_id/delete" do
  list_id = params[:list_id].to_i
  list = list_valid?(list_id)

  session[:lists].delete(list)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted"
    redirect "/lists"
  end
end

#add a todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  list = list_valid?(@list_id)
  todo_name = params[:todo_name].strip

  if error_for_todo(todo_name)
    erb :list, layout: :layout
  else
    id = next_id(list[:todos])
    list[:todos] << { name: todo_name, id: id, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

#delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = list_valid?(list_id)
  todo = select_todo(list[:todos], todo_id)

  list[:todos].delete(todo)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

#toggle todo as complete
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = list_valid?(list_id)
  todo = select_todo(list[:todos], todo_id)

  todo[:completed] = (params[:completed] == "true")
  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end

#mark all todos as complete
post "/lists/:list_id/complete" do
  list_id = params[:list_id].to_i
  list = list_valid?(list_id)
  todos = list[:todos]

  complete_all(todos)
  session[:success] = "All todos have been completed"
  redirect "/lists/#{list_id}"
end