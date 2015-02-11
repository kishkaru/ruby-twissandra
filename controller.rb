require_relative 'cass'

class Controller
  @@db = Cass.new

  # User actions
  def self.create_user(username, password)
    @@db.save_user(username, password)
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
    @@db.remove(username, friend_username)
  end

  # Activity retrieval
  def self.get_user_tweets(username)
    @@db.get_usertweets(username)
  end

  def self.get_activity_feed(username)
    @@db.get_timeline(username)
  end

  # Tweets
  def self.create_new_tweet(username, tweet)
    generator = Cassandra::Uuid::Generator.new
    tweet_id = generator.uuid
    @@db.save_tweet(tweet_id, username, tweet)
  end

end