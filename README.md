ruby-twissandra
===============

## Install dependencies
```
bundle install

# Create Cassandra schema
ruby setup/create_schema.rb
```

## Running server locally
### Run Sinatra server (via Thin)
```
ruby runserver.rb
```

## Deploying server via Unicorn & Nginx
### Run Sinatra server (via Unicorn)
```
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
