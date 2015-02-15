require 'sinatra'
require 'rack-flash'
require 'erb'

require_relative 'controller'

configure do
  enable :sessions
  set :session_secret, 'super secret'
  set :views, settings.root + '/public/views'
  use Rack::Flash, :sweep => true
end

# INDEX (LOADS PUBLIC USER)

get '/' do
  public_user = "!PUBLIC!"
  #Controller.create_user("Public", "User", public_user, "super_secret")

  if params['paging_direction'] == nil
    tweets_and_paging = Controller.get_user_tweets(public_user, session['paging_state'], "new_query")
  elsif params['paging_direction'] == "previous"
    tweets_and_paging = Controller.get_user_tweets(public_user, session['paging_state'], "previous")
  else params['paging_direction'] == "next"
    tweets_and_paging = Controller.get_user_tweets(public_user, session['paging_state'], "next")
  end

  tweets_ids_and_timestamps = tweets_and_paging[0]
  session['paging_state'] = tweets_and_paging[1]
  paging_state = session['paging_state']

  erb :public_feed, :locals => { :username => public_user, :tweets => tweets_ids_and_timestamps, 
                                  :paging_state => paging_state, :flash => flash[:notice] }
end

# AUTH ROUTES

get '/login' do
  if session['username'] != nil
    flash[:notice] = "You're already signed in"
    redirect to("/")
  end
  
  erb :login_page, :locals => { :flash => flash[:notice] }
end

post '/login' do
  user = Controller.get_user(params['inputUsername'])

  if user == nil
    flash[:notice] = "Incorrect username or password"
    redirect to("/login")
  elsif user['username'] == params['inputUsername'] && user['password'] == params['inputPassword']
    session['username'] = user['username']
    flash[:notice] = "Logged in as #{user['username']}"
    redirect back
  else
    flash[:notice] = "Incorrect username or password"
    redirect to("/login")
  end
end

get '/logout' do
  flash[:notice] = "Successfully logged out of #{session['username']}"
  session['username'] = nil

  redirect to("/")
end

# USER ROUTES

get '/signup' do
  erb :signup_page, :locals => { :flash => flash[:notice] }
end

post '/signup' do
  Controller.create_user(params['firstname'], params['lastname'], params['inputUsername'], params['inputPassword'])
  session['username'] = params['inputUsername']
  flash[:notice] = "Thanks for signing up, #{params['firstname']}!"
  
  redirect to("/user/#{params['inputUsername']}")
end

post '/changepassword' do
  username = session['username']
  user = Controller.get_user(username)

  if user['password'] == params['curr_password']
    Controller.create_user(user['firstname'], user['lastname'], user['username'], params['curr_password'])
  
    flash[:notice] = "Password successfully changed for #{username}"
    redirect back
  else
    flash[:notice] = "Incorrect current password"
    redirect back
  end
end

post '/deleteaccount' do
  username = session['username']
  if username == nil
    flash[:notice] = "Login first to delete your account"
    redirect to("/login")
  end

  user = Controller.get_user(username)
  if user == nil
    flash[:notice] = "User #{username} does not exist"
  else
    Controller.remove_user(username)
    session['username'] = nil
    flash[:notice] = "User #{username}'s account has been deleted"
  end

  redirect to("/")
end

# FRIEND ROUTES

post '/addfriend' do
  username = session['username']
  friend_username = params['friend_username']
  
  if friend_username == username
    flash[:notice] = "Cannot add yourself as your friend"
    redirect back
  elsif Controller.get_user(friend_username) == nil
    flash[:notice] = "#{friend_username} does not exist"
    redirect back
  end
    
  Controller.add_friend(username, friend_username)
  flash[:notice] = "#{params['friend_username']} has been added as a friend"

  redirect back
end

post '/removefriend' do
  username = session['username']
  friend_username = params['friend_username']
  
  friends = Controller.get_friends(username)
  if friends.include?(friend_username)
    Controller.remove_friend(username, friend_username)
    flash[:notice] = "#{friend_username} has been removed as a friend"
    redirect back
  else
    flash[:notice] = "#{friend_username} is not your friend"
    redirect back
  end
end

# TWEET ROUTES

get '/newtweet' do
  erb :new_tweet, :locals => { :flash => flash[:notice] }
end

post '/newtweet' do
  username = session['username']
  tweet = params['tweet']
  Controller.create_new_tweet(username, tweet)

  flash[:notice] = "Posted a new tweet as #{username}!"

  redirect to("/activityfeed")
end

post '/removetweet' do
  username = params['username']
  tweet_id = params['tweet_id']
  time = params['time']
  body = params['tweet-body']

  if username != session['username']
    flash[:notice] = "You can only remove your own tweets"
    redirect back
  end

  Controller.remove_tweet(username, tweet_id, time)

  flash[:notice] = "Tweet '#{body}' has been removed"

  redirect back
end

# ACTIVITY ROUTES

get '/user/:user' do
  username = params['user']
  user = Controller.get_user(params['user'])
  if user == nil
    flash[:notice] = "User #{username} does not exist"
    redirect to("/")
  end

  p session['username']
  p username == session['username']

  friends = Controller.get_friends(username)
  followers = Controller.get_followers(username)

  if params['paging_direction'] == nil
    tweets_and_paging = Controller.get_user_tweets(params['user'], session['paging_state'], "new_query")
  elsif params['paging_direction'] == "previous"
    tweets_and_paging = Controller.get_user_tweets(params['user'], session['paging_state'], "previous")
  else params['paging_direction'] == "next"
    tweets_and_paging = Controller.get_user_tweets(params['user'], session['paging_state'], "next")
  end

  tweets_ids_and_timestamps = tweets_and_paging[0]
  session['paging_state'] = tweets_and_paging[1]
  paging_state = session['paging_state']

  erb :user_profile, :locals => { :user => user, :friends => friends, :followers => followers,
                                :tweets => tweets_ids_and_timestamps, :paging_state => paging_state, 
                                :flash => flash[:notice] }
end

get '/activityfeed' do
  if session['username'] == nil
    flash[:notice] = "Login first to see your Activity Feed"
    redirect to("/login")
  end

  user = Controller.get_user(session['username'])

  if params['paging_direction'] == nil
    tweets_and_paging = Controller.get_activity_feed(session['username'], session['paging_state'], "new_query")
  elsif params['paging_direction'] == "previous"
    tweets_and_paging = Controller.get_activity_feed(session['username'], session['paging_state'], "previous")
  else params['paging_direction'] == "next"
    tweets_and_paging = Controller.get_activity_feed(session['username'], session['paging_state'], "next")
  end

  tweets_ids_and_timestamps = tweets_and_paging[0]
  session['paging_state'] = tweets_and_paging[1]
  paging_state = session['paging_state']

  erb :activity_feed, :locals => { :user => user, :tweets => tweets_ids_and_timestamps, :paging_state => paging_state,
                                :flash => flash[:notice] }
end

