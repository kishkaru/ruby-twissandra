require 'cassandra'

$cluster = Cassandra.cluster
$session = $cluster.connect("twissandra")

$public_user = "!PUBLIC!"

## Retrieval APIs

def get_line(tablename, username, start, limit)
  if start == nil
    time_clause = ""
    params = [username, limit]
  else
    time_clause = "AND time < ?"
    params = [username, start, limit]
  end

  select_tweet_id = $session.prepare("SELECT time, tweet_id FROM #{tablename} WHERE username=? #{time_clause} LIMIT ?")

  results = $session.execute(select_tweet_id, arguments: params)
  if results.empty?
    return [], nil
  end

  if results.size == limit
    timeuuids = results.map do |row|
      row['time']
    end

    oldest_timeuuid = timeuuids.min
  else
    oldest_timeuuid = nil
  end

  tweets = results.map do |row|
    get_tweet(row['tweet_id'])
  end

  [tweets, oldest_timeuuid]
end

# Given a username, gets the user's record
def get_user_by_username(username)
  select = $session.prepare("SELECT * FROM users WHERE username=?")
  result = $session.execute(select, arguments: [username]).first

  if result == nil
    raise "User #{username} not found."
  else
    result
  end
end

# Given a list of usernames, gets an associated list of user records
def get_users_for_usernames(usernames)
  select = $session.prepare("SELECT * FROM users WHERE username=?")
  
  users = []
  usernames.each do |username|
    result = $session.execute(select, arguments: [username]).first

    if result == nil
      raise "User #{username} not found."
    else
      users.push(result['username'])
    end
  end

  users
end

# Given a username, gets the user's friends' usernames
def get_friend_usernames(username, count=5000)
  select = $session.prepare("SELECT friend_username FROM friends WHERE username=? LIMIT ?")
  results = $session.execute(select, arguments: [username, count])

  friend_usernames = results.map do |row|
    row['friend_username']
  end

  friend_usernames
end

# Given a username, gets the user's followers' usernames
def get_follower_usernames(username, count=5000)
  select = $session.prepare("SELECT follower_username FROM followers WHERE username=? LIMIT ?")
  results = $session.execute(select, arguments: [username, count])

  follower_usernames = results.map do |row|
    row['follower_username']
  end

  follower_usernames
end

# Given a username, gets the user records for the user's friends
def get_friends(username, count=5000)
  friend_usernames = get_friend_usernames(username, count)
  users = get_users_for_usernames(friend_usernames)
  return users
end

# Given a username, gets the user records for the user's followers
def get_followers(username, count=5000)
  follower_usernames = get_follower_usernames(username, count)
  users = get_users_for_usernames(follower_usernames)
  return users
end

# Given a username, gets the user's friends' tweets
def get_timeline(username, start=nil, limit=40)
  get_line("timeline", username, start, limit)
end

# Given a username, gets the user's tweets
def get_usertweets(username, start=nil, limit=40)
  get_line("usertweets", username, start, limit)
end

# Given a tweet_id, gets the tweet's record
def get_tweet(tweet_id)
  select = $session.prepare("SELECT * FROM tweets WHERE tweet_id=?")
  result = $session.execute(select, arguments: [tweet_id]).first

  if result == nil
    raise "Tweet #{tweet_id} not found."
  else
    result
  end
end

# Given a list of tweet_ids, gets an associated list of tweet records
def get_tweet_for_tweet_ids(tweet_ids)
  select = $session.prepare("SELECT * FROM tweets WHERE tweet_id=?")
  
  tweets = []
  tweet_ids.each do |tweet_id|
    result = $session.execute(select, arguments: [tweet_id]).first

    if result == nil
      raise "Tweet #{tweet_id} not found."
    else
      tweets.push(result)
    end
  end

  tweets
end

## Insertion APIs

def save_user(username, password)
  insert = $session.prepare("INSERT INTO users (username, password) VALUES (?, ?)")
  $session.execute(insert, arguments: [username, password])
end

def save_tweet(tweet_id, username, tweet, timestamp=nil)
  insert_tweet = $session.prepare("INSERT INTO tweets (tweet_id, username, body) VALUES (?, ?, ?)")
  insert_usertweets = $session.prepare("INSERT INTO usertweets (username, time, tweet_id) VALUES (?, ?, ?)")
  insert_timeline = $session.prepare("INSERT INTO timeline (username, time, tweet_id) VALUES (?, ?, ?)")

  generator = Cassandra::Uuid::Generator.new
  if timestamp == nil  
    timeuuid = generator.now
  else
    timeuuid  = generator.at(timestamp)
  end

  # Insert the tweet
  $session.execute(insert_tweet, arguments: [tweet_id, username, tweet])
  # Insert the tweet into the user's tweets
  $session.execute(insert_usertweets, arguments: [username, timeuuid, tweet_id])
  # Insert the tweet into PUBLIC's tweets
  $session.execute(insert_usertweets, arguments: [$public_user, timeuuid, tweet_id])

  # Insert the tweet into the user's timeline and the users' followers' timeline
  follower_usernames = get_follower_usernames(username)
  follower_usernames.push(username)

  follower_usernames.each do |follower_username|
    $session.execute(insert_timeline, arguments: [follower_username, timeuuid, tweet_id])
  end
end

def add_friend(from_username, to_username)
  if from_username == to_username
    raise "Can't friend yourself"
  end

  insert_friend = $session.prepare("INSERT INTO friends (username, friend_username, since) VALUES (?, ?, ?)")
  insert_follower = $session.prepare("INSERT INTO followers (username, follower_username, since) VALUES (?, ?, ?)")

  timestamp = Time.now

  # Friend the user (follow him/her)
  $session.execute(insert_friend, arguments: [from_username, to_username, timestamp])

  # Add yourself as a follower of that user
  $session.execute(insert_follower, arguments: [to_username, from_username, timestamp])
end

def remove_friend(from_username, to_username)
  if from_username == to_username
    raise "Can't unfriend yourself"
  end

  remove_friend = $session.prepare("DELETE FROM friends WHERE username=? AND friend_username=?")
  remove_follower = $session.prepare("DELETE FROM followers WHERE username=? AND follower_username=?")

  # Unfriend the user (stop following him/her)
  $session.execute(remove_friend, arguments: [from_username, to_username])

  # Remove yourself as a follower of that user
  $session.execute(remove_follower, arguments: [to_username, from_username])
end
