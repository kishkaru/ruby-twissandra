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
  Controller.create_user(params['username'], params['password'])
  flash[:notice] = "Thanks for signing up, #{params['username']}!"
  
  redirect to("/user/#{params['username']}/profile")
end

# FRIEND ROUTES

post '/addfriend' do
  username = params['username']
  friend_username = params['friend_username']
  Controller.add_friend(username, friend_username)

  flash[:notice] = "#{params['friend_username']} has been added as a friend!"

  redirect back
end

post '/removefriend' do
  username = params['username']
  friend_username = params['friend_username']
  Controller.remove_friend(username, friend_username)

  flash[:notice] = "#{params['friend_username']} has been removed as a friend!"

  redirect back
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

get '/activityfeed/:user' do
  tweets_and_paging = Controller.get_activity_feed(params['user'])
  tweets_and_timestamps = tweets_and_paging[0]
  erb :activityfeed, :locals => { :username => params['user'], :tweets => tweets_and_timestamps, :flash => flash[:notice] }
end

