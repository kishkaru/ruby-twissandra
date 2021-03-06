ruby-twissandra
===============

## Install dependencies
```
bundle install

# Create Cassandra schema
ruby setup/create_schema.rb
```

## Running server locally (via Thin)
```
ruby runserver.rb
```

## Running hosted server (via Unicorn)
```
# Update app_dir in unicorn.rb
# mkdir for /pids and /logs

unicorn -c unicorn.rb -D
```

### Sample Nginx coniguration
```
upstream app {
    # Path to Unicorn SOCK file
    server unix:/tmp/unicorn.twissandra.sock fail_timeout=0;
}

server {
    listen 80;

    server_name twissandra.karu.io;

    # Application root, as defined previously
    root /home/ruby-twissandra;

    try_files $uri/index.html $uri @app;

    location @app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://app;
    }

    error_page 500 502 503 504 /500.html;
    client_max_body_size 4G;
    keepalive_timeout 10;
    location = /favicon.ico { alias /home/ruby-twissandra/favicon.ico; }
}
```

## Feature wishlist
* Profile picture for users & tweets
* Ability to add comments to tweets 
* Jquery to streamline UI
