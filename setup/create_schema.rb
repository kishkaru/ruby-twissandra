require 'cassandra'

cluster = Cassandra.cluster
session = cluster.connect

result = session.execute("SELECT * FROM system.schema_keyspaces WHERE keyspace_name='twissandra'").first

unless result == nil
	print "It looks like you have an existing twissandra schema and data. 
          Do you want to delete and recreate it? (y/n): "
  choice = gets
  if choice == nil || choice[0] != 'y'
    puts "Okay, no changes have been made. Exiting."
    return
  end

  session.execute("DROP KEYSPACE twissandra")
end

# Create the keyspace
session.execute("CREATE KEYSPACE twissandra WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} ")

# Create the tables
session.execute("USE twissandra")

session.execute("
    CREATE TABLE users (
        username text PRIMARY KEY,
        password text)
    ")

session.execute("
    CREATE TABLE friends (
        username text,
        friend_username text,
        since timestamp,
        PRIMARY KEY (username, friend_username))
    ")

session.execute("
    CREATE TABLE followers (
        username text,
        follower_username text,
        since timestamp,
        PRIMARY KEY (username, follower_username))
    ")

session.execute("
    CREATE TABLE tweets (
        tweet_id uuid PRIMARY KEY,
        username text,
        body text)
    ")

session.execute("
    CREATE TABLE usertweets (
        username text,
        time timeuuid,
        tweet_id uuid,
        PRIMARY KEY (username, time)
    ) WITH CLUSTERING ORDER BY (time DESC)
    ")

session.execute("
    CREATE TABLE timeline (
        username text,
        time timeuuid,
        tweet_id uuid,
        PRIMARY KEY (username, time)
    ) WITH CLUSTERING ORDER BY (time DESC)
    ")

cluster.close
puts "Schema creation complete."