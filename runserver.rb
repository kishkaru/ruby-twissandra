require 'sinatra'

get '/' do
  status, headers, body = call env.merge("PATH_INFO" => '/users/public')
  [status, headers, body.map(&:upcase)]
end

get '/users/:user' do
  "Getting #{params['user']}'s profile"
end

get '/activityfeed/:user' do
  "Getting activityfeeed for #{params['user']}"
end
