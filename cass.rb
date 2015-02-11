require 'cassandra'

class Cass

  @cluster = nil
  @session = nil
  @public_user = nil

  @select_tweet_id_query = nil
  @select_user_query = nil
  @select_friend_username_query = nil
  @select_follower_username_query = nil
  @select_tweet_query = nil

  @insert_user_query = nil
  @insert_tweet_query = nil
  @insert_usertweets_query = nil
  @insert_timeline_query = nil
  @insert_friend_query = nil
  @insert_follower_query = nil

  @remove_friend_query = nil
  @remove_follower_query = nil

  def initialize
    @cluster = Cassandra.cluster
    @session = @cluster.connect("twissandra")

    @public_user = "!PUBLIC!"
  end

  ## Retrieval APIs

  def get_line(tablename, username, start, limit)
    if start == nil
      time_clause = ""
      params = [username, limit]
    else
      time_clause = "AND time < ?"
      params = [username, start, limit]
    end

    # This query changes based on whether new or paged. It must be re-prepared each time.
    select_tweet_id_query = @session.prepare("SELECT time, tweet_id FROM #{tablename} WHERE username=? #{time_clause} LIMIT ?")

    results = @session.execute(select_tweet_id_query, arguments: params)
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
      [get_tweet(row['tweet_id']), row['time'].to_time]
    end

    [tweets, oldest_timeuuid]
  end

  # Given a username, gets the user's record
  def get_user_by_username(username)
    @select_user_query ||= @session.prepare("SELECT * FROM users WHERE username=?")
    @session.execute(@select_user_query, arguments: [username]).first

    # can return nil here if user doesn't exist
  end

  # Given a list of usernames, gets an associated list of user records
  def get_users_for_usernames(usernames)
    @select_user_query ||= @session.prepare("SELECT * FROM users WHERE username=?")
    
    users = []
    usernames.each do |username|
      result = @session.execute(@select_user_query, arguments: [username]).first

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
    @select_friend_username_query ||= @session.prepare("SELECT friend_username FROM friends WHERE username=? LIMIT ?")
    results = @session.execute(@select_friend_username_query, arguments: [username, count])

    friend_usernames = results.map do |row|
      row['friend_username']
    end

    friend_usernames
  end

  # Given a username, gets the user's followers' usernames
  def get_follower_usernames(username, count=5000)
    @select_follower_username_query ||= @session.prepare("SELECT follower_username FROM followers WHERE username=? LIMIT ?")
    results = @session.execute(@select_follower_username_query, arguments: [username, count])

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
    @select_tweet_query ||= @session.prepare("SELECT * FROM tweets WHERE tweet_id=?")
    result = @session.execute(@select_tweet_query, arguments: [tweet_id]).first

    if result == nil
      raise "Tweet #{tweet_id} not found."
    else
      result
    end
  end

  # Given a list of tweet_ids, gets an associated list of tweet records
  def get_tweet_for_tweet_ids(tweet_ids)
    @select_tweet_query ||= @session.prepare("SELECT * FROM tweets WHERE tweet_id=?")
    
    tweets = []
    tweet_ids.each do |tweet_id|
      result = @session.execute(@select_tweet_query, arguments: [tweet_id]).first

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
    @insert_user_query ||= @session.prepare("INSERT INTO users (username, password) VALUES (?, ?)")
    @session.execute(@insert_user_query, arguments: [username, password])
  end

  def save_tweet(tweet_id, username, tweet, timestamp=nil)
    @insert_tweet_query ||= @session.prepare("INSERT INTO tweets (tweet_id, username, body) VALUES (?, ?, ?)")
    @insert_usertweets_query ||= @session.prepare("INSERT INTO usertweets (username, time, tweet_id) VALUES (?, ?, ?)")
    @insert_timeline_query ||= @session.prepare("INSERT INTO timeline (username, time, tweet_id) VALUES (?, ?, ?)")

    generator = Cassandra::Uuid::Generator.new
    if timestamp == nil  
      timeuuid = generator.now
    else
      timeuuid  = generator.at(timestamp)
    end

    # Insert the tweet
    @session.execute(@insert_tweet_query, arguments: [tweet_id, username, tweet])
    # Insert the tweet into the user's tweets
    @session.execute(@insert_usertweets_query, arguments: [username, timeuuid, tweet_id])
    # Insert the tweet into PUBLIC's tweets
    @session.execute(@insert_usertweets_query, arguments: [@public_user, timeuuid, tweet_id])

    # Insert the tweet into the user's timeline and the users' followers' timeline
    follower_usernames = get_follower_usernames(username)
    follower_usernames.push(username)

    follower_usernames.each do |follower_username|
      @session.execute(@insert_timeline_query, arguments: [follower_username, timeuuid, tweet_id])
    end
  end

  def add_friend(from_username, to_username)
    if from_username == to_username
      raise "Can't friend yourself"
    end

    if get_user_by_username(to_username) == nil
      raise "User #{to_username} does not exist."
    end

    @insert_friend_query ||= @session.prepare("INSERT INTO friends (username, friend_username, since) VALUES (?, ?, ?)")
    @insert_follower_query ||= @session.prepare("INSERT INTO followers (username, follower_username, since) VALUES (?, ?, ?)")

    timestamp = Time.now

    # Friend the user (follow him/her)
    @session.execute(@insert_friend_query, arguments: [from_username, to_username, timestamp])

    # Add yourself as a follower of that user
    @session.execute(@insert_follower_query, arguments: [to_username, from_username, timestamp])
  end

  def remove_friend(from_username, to_username)
    if from_username == to_username
      raise "Can't unfriend yourself"
    end

    @remove_friend_query ||= @session.prepare("DELETE FROM friends WHERE username=? AND friend_username=?")
    @remove_follower_query ||= @session.prepare("DELETE FROM followers WHERE username=? AND follower_username=?")

    # Unfriend the user (stop following him/her)
    @session.execute(@remove_friend_query, arguments: [from_username, to_username])

    # Remove yourself as a follower of that user
    @session.execute(@remove_follower_query, arguments: [to_username, from_username])
  end

end