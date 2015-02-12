require_relative 'cass'

class Controller
  @@db = Cass.new

  # User actions
  def self.create_user(firstname, lastname, username, password)
    @@db.save_user(firstname, lastname, username, password)
  end

  def self.get_user(username)
    @@db.get_user_by_username(username)
  end

  # Friend actions
  def self.get_friends(username)
    @@db.get_friends(username)
  end

  def self.get_followers(username)
    @@db.get_followers(username)
  end

  def self.add_friend(username, friend_username)
    @@db.add_friend(username, friend_username)
  end

  def self.remove_friend(username, friend_username)
    @@db.remove_friend(username, friend_username)
  end

  # Activity retrieval
  def self.get_user_tweets(username, paging_state, direction)
    # Check edge case where returning to first page
    if direction == "previous" && paging_state[-3] == nil
      return @@db.get_usertweets(username, paging_state, "new_query")
    end

    @@db.get_usertweets(username, paging_state, direction)
  end

  def self.get_activity_feed(username, paging_state, direction)
    # Check edge case where returning to first page
    if direction == "previous" && paging_state[-3] == nil
      return @@db.get_timeline(username, paging_state, "new_query")
    end

    @@db.get_timeline(username, paging_state, direction)
  end

  # Tweets
  def self.create_new_tweet(username, tweet)
    generator = Cassandra::Uuid::Generator.new
    tweet_id = generator.uuid
    @@db.save_tweet(tweet_id, username, tweet)
  end

  def self.remove_tweet(username, tweet_id, time)
    tweet_id = Cassandra::Uuid.new(tweet_id)
    time = Cassandra::TimeUuid.new(time)

    @@db.remove_tweet(tweet_id, username, time)
  end

end