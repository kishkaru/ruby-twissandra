app_name = "twissandra"
app_dir = "/home/kishan/git/ruby-twissandra"

# Set the working application directory
# working_directory "/path/to/your/app"
working_directory app_dir

# Unicorn PID file location
# pid "/path/to/pids/unicorn.pid"
pid "#{app_dir}/pids/unicorn.pid"

# Path to logs
# stderr_path "/path/to/logs/unicorn.log"
# stdout_path "/path/to/logs/unicorn.log"
stderr_path "#{app_dir}/logs/unicorn.log"
stdout_path "#{app_dir}/logs/unicorn.log"

# Unicorn socket
# listen "/tmp/unicorn.[app name].sock"
listen "/tmp/unicorn.#{app_name}.sock"

# Number of processes
# worker_processes 4
worker_processes 2

# Time-out
timeout 30