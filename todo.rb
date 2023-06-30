require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"

configure do
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

#sets the first list's id to 0 and the rest are incremented from the last
def list_id
  if session[:lists].empty?
    return 0
  else
    return session[:lists][-1][:id] + 1
  end
end

#sets the first todo id to 0 and the rest are incremented from the last
def todo_id(todos)
  if todos.empty?
    return 0
  else
    return todos[-1][:id] + 1
  end
end

#updates all list ids when one is deleted. corresponds with index place
def update_list_ids
  session[:lists].each_with_index do |list, idx|
    list[:id] = idx
  end
end

#updates all todo ids when one is deleted.
def update_todo_ids(todos)
  todos.each_with_index do |todo, idx|
    todo[:id] = idx
  end
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
    session[:success] = "The list has been added successfully."
    session[:lists] << { name: list_name, id: list_id(), todos: [] }
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
  @list = session[:lists][@list_id]
  @todos = @list[:todos]

  erb :list
end

#Edit a list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  erb :edit_list, layout: :layout
end

#updates a list
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  list_name = params[:list_name].strip
  @list = session[:lists][@list_id]

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

  session[:lists].delete_at(list_id)
  update_list_ids()
  session[:success] = "The list has been deleted"
  redirect "/lists"
end

#add a todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todos = @list[:todos]
  todo_name = params[:todo_name].strip

  if error_for_todo(todo_name)
    erb :list, layout: :layout
  else
    todos << { name: todo_name, id: todo_id(todos), completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

#delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todos = session[:lists][list_id][:todos]

  todos.delete_at(todo_id)
  update_todo_ids(todos)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{list_id}"
end

#toggle todo as complete
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todos = session[:lists][list_id][:todos]

  todos[todo_id][:completed] = (params[:completed] == "true")
  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end

#mark all todos as complete
post "/lists/:list_id/complete" do
  list_id = params[:list_id].to_i
  todos = session[:lists][list_id][:todos]

  complete_all(todos)
  session[:success] = "All todos have been completed"
  redirect "/lists/#{list_id}"
end