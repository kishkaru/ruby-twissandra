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

  @delete_tweet_query = nil
  @delete_usertweets_query = nil
  @delete_timeline_query = nil
  @remove_friend_query = nil
  @remove_timeline_query = nil
  @remove_follower_query = nil

  def initialize
    @cluster = Cassandra.cluster
    @session = @cluster.connect("twissandra")

    @public_user = "!PUBLIC!"
  end

  ## Retrieval APIs

  def get_line(tablename, username, paging_state, direction, limit)
    if direction == "new_query"
      time_clause = ""
      params = [username]
    elsif direction == "previous"
      time_clause = "AND time < ?"
      params = [username, paging_state[-3]]
    elsif direction == "next"
      time_clause = "AND time < ?"
      params = [username, paging_state[-1]]
    end

    # This query changes based on whether new or paged. It must be re-prepared each time.
    select_tweet_id_query = @session.prepare("SELECT time, tweet_id FROM #{tablename} WHERE username=? #{time_clause}")

    results = @session.execute(select_tweet_id_query, arguments: params, page_size: limit)

    # Check if there is any more pages. This is a C* bug where results.last_page? returns false on empty next page
    if results.size == limit
      timeuuids = results.map do |row|
        row['time']
      end
    
      next_start = timeuuids.min

      params = [username, next_start]
      next_result = @session.execute("SELECT time, tweet_id FROM #{tablename} WHERE username=? AND time < ?", arguments: [username, next_start])

      if next_result.empty?
        next_start = nil
      end
    end

    tweets = results.map do |row|
      [get_tweet(row['tweet_id']), row['tweet_id'], row['time']]
    end

    if direction == "new_query"
      [tweets, [nil, next_start]]
    elsif direction == "previous"
      [tweets, paging_state[0...-2].push(next_start)]
    elsif direction == "next"
      [tweets, paging_state.push(next_start)]
    end
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
  def get_timeline(username, paging_state, direction, limit=10)
    get_line("timeline", username, paging_state, direction, limit)
  end

  # Given a username, gets the user's tweets
  def get_usertweets(username, paging_state, direction, limit=10)
    get_line("usertweets", username, paging_state, direction, limit)
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

  def save_user(firstname, lastname, username, password)
    @insert_user_query ||= @session.prepare("INSERT INTO users (firstname, lastname, username, password) VALUES (?, ?, ?, ?)")
    @session.execute(@insert_user_query, arguments: [firstname, lastname, username, password])
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

  def remove_tweet(tweet_id, username, timestamp)
    @delete_tweet_query ||= @session.prepare("DELETE FROM tweets WHERE tweet_id=?")
    @delete_usertweets_query ||= @session.prepare("DELETE FROM usertweets WHERE username=? AND time=?")
    @delete_timeline_query ||= @session.prepare("DELETE FROM timeline WHERE username=? AND time=?")

    # Remove the tweet
    @session.execute(@delete_tweet_query, arguments: [tweet_id])
    # Remove the tweet from the user's tweets
    @session.execute(@delete_usertweets_query, arguments: [username, timestamp])
    # Remove the tweet from PUBLIC's tweets
    @session.execute(@delete_usertweets_query, arguments: [@public_user, timestamp])

    # Remove the tweet from the user's timeline and the users' followers' timeline
    follower_usernames = get_follower_usernames(username)
    follower_usernames.push(username)

    follower_usernames.each do |follower_username|
      @session.execute(@delete_timeline_query, arguments: [follower_username, timestamp])
    end
  end


  def add_friend(from_username, to_username)
    @insert_friend_query ||= @session.prepare("INSERT INTO friends (username, friend_username, since) VALUES (?, ?, ?)")
    @insert_timeline_query ||= @session.prepare("INSERT INTO timeline (username, time, tweet_id) VALUES (?, ?, ?)")
    @insert_follower_query ||= @session.prepare("INSERT INTO followers (username, follower_username, since) VALUES (?, ?, ?)")

    timestamp = Time.now

    # Friend the user (follow him/her)
    @session.execute(@insert_friend_query, arguments: [from_username, to_username, timestamp])

    # Grab all his/her past tweets into your timeline
    @select_tweet_id_query ||= @session.prepare("SELECT time, tweet_id FROM usertweets WHERE username=?")
    results = @session.execute(@select_tweet_id_query, arguments: [to_username])

    results.each do |tweet|
      @session.execute(@insert_timeline_query, arguments: [from_username, tweet['time'], tweet['tweet_id']])
    end

    # Add yourself as a follower of that user
    @session.execute(@insert_follower_query, arguments: [to_username, from_username, timestamp])
  end

  def remove_friend(from_username, to_username)
    @remove_friend_query ||= @session.prepare("DELETE FROM friends WHERE username=? AND friend_username=?")
    @remove_timeline_query ||= @session.prepare("DELETE FROM timeline WHERE username=? AND time=?")
    @remove_follower_query ||= @session.prepare("DELETE FROM followers WHERE username=? AND follower_username=?")

    # Unfriend the user (stop following him/her)
    @session.execute(@remove_friend_query, arguments: [from_username, to_username])

    # Remove all his/her tweets from your timeline
    @select_tweet_id_query ||= @session.prepare("SELECT time, tweet_id FROM usertweets WHERE username=?")
    results = @session.execute(@select_tweet_id_query, arguments: [to_username])

    results.each do |tweet|
      @session.execute(@remove_timeline_query, arguments: [from_username, tweet['time']])
    end

    # Remove yourself as a follower of that user
    @session.execute(@remove_follower_query, arguments: [to_username, from_username])
  end

end