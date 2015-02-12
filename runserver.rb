require 'sinatra'
require 'rack-flash'
require 'erb'

require_relative 'controller'

enable :sessions
set :session_secret, 'super secret'
use Rack::Flash, :sweep => true

# INDEX (LOADS PUBLIC USER)

get '/' do
  status, headers, body = call env.merge("PATH_INFO" => '/user/!PUBLIC!')
end

# AUTH ROUTES

get '/login' do
  erb :login_page, :locals => { :flash => flash[:notice] }
end

post '/login' do
  user = Controller.get_user(params['username'])

  if user['username'] == params['username'] && user['password'] == params['password']
    session['username'] = params['username']
    flash[:notice] = "Logged in as #{params['username']}"
    redirect to("/user/#{params['username']}/profile")
  else
    flash[:notice] = "Incorrect username or password"
    redirect to("/login")
  end
end

get '/logout' do
  session['username'] = nil
  flash[:notice] = "Successfully logged out"

  redirect to("/")
end

# USER ROUTES

get '/user/:user/profile' do
  username = params['user']
  friends = Controller.get_friends(username)
  followers = Controller.get_followers(username)
  
  erb :user_profile, :locals => { :username => username, :friends => friends, 
                                  :followers => followers, :flash => flash[:notice] }
end

get '/signup' do
  erb :newuser
end

post '/signup' do
  Controller.create_user(params['firstname'], params['lastname'], params['username'], params['password'])
  session['username'] = params['username']
  flash[:notice] = "Thanks for signing up, #{params['firstname']}!"
  
  redirect to("/user/#{params['username']}/profile")
end

# FRIEND ROUTES

post '/addfriend' do
  username = session['username']
  p username
  friend_username = params['friend_username']
  
  if friend_username == username
    flash[:notice] = "Cannot add yourself as your friend"
    redirect back
  elsif Controller.get_user(friend_username) == nil
    flash[:notice] = "#{friend_username} does not exist"
    redirect back
  end
    
  Controller.add_friend(username, friend_username)
  flash[:notice] = "#{params['friend_username']} has been added as a friend!"

  redirect back
end

post '/removefriend' do
  username = session['username']
  friend_username = params['friend_username']
  
  friends = Controller.get_friends(username)
  if friends.include?(friend_username)
    Controller.remove_friend(username, friend_username)
    flash[:notice] = "#{friend_username} has been removed as a friend!"
    redirect back
  else
    flash[:notice] = "#{friend_username} is not your friend"
    redirect back
  end
end

# TWEET ROUTES

get '/newtweet' do
  erb :newtweet, :locals => { :flash => flash[:notice] }
end

post '/newtweet' do
  username = session['username']
  tweet = params['tweet']
  Controller.create_new_tweet(username, tweet)

  flash[:notice] = "Posted a new tweet as #{username}!"

  redirect back
end

# ACTIVITY ROUTES

get '/user/:user' do
  tweets_and_paging = Controller.get_user_tweets(params['user'])
  tweets_and_timestamps = tweets_and_paging[0]
  erb :tweet_feed, :locals => { :username => params['user'], :tweets => tweets_and_timestamps, :flash => flash[:notice] }
end

get '/activityfeed' do
  tweets_and_paging = Controller.get_activity_feed(session['username'])
  tweets_and_timestamps = tweets_and_paging[0]
  erb :activity_feed, :locals => { :username => session['username'], :tweets => tweets_and_timestamps, :flash => flash[:notice] }
end

