require 'sinatra'
require 'sinatra/reloader'
require 'rest-client'
require 'json'
require 'dotenv/load'

GITHUB_CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
GITHUB_CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']
SO_CLIENT_ID = ENV['SO_CLIENT_ID']
SO_SECRET = ENV['SO_SECRET']

get '/' do
  erb :index, :locals => {:github_client_id => GITHUB_CLIENT_ID, :so_client_id => SO_CLIENT_ID}
end

get '/gh_callback' do
  # get temporary GitHub code...
  session_code = request.env['rack.request.query_hash']['code']

  # ... and POST it back to GitHub
  result = RestClient.post('https://github.com/login/oauth/access_token',
                          {:client_id => GITHUB_CLIENT_ID,
                           :client_secret => GITHUB_CLIENT_SECRET,
                           :code => session_code}.to_json,
                           {content_type: "application/x-www-form-urlencoded", accept: :json})

  # extract the token and granted scopes
  access_token = JSON.parse(result)['access_token']

  scopes = JSON.parse(result)['scope'].split(',')
  has_user_email_scope = scopes.include? 'user:email'
  print '#######'
  print access_token
  print '#######'
  # erb :home, :locals => {:access_token => access_token}
end

get '/so_callback' do
  session_code = request.env['rack.request.query_hash']['code']
  print session_code


  payload = { 
    :client_id => SO_CLIENT_ID,
    :client_secret => SO_SECRET,
    :redirect_uri => "localhost:4567"
  }

  url = 'https://stackoverflow.com/oauth/access_token'
  result = rest_client_post_request(url, payload)
  # extract the token and granted scopes
  access_token = result.second['access_token']

  print '#######'
  print JSON.parse(result)
  print access_token
  print '#######'
end

def rest_client_post_request(url, payload, access_token: nil)
  begin
    RestClient.log = 'stdout'

    headers = { :accept => :json, content_type: :json }

    unless access_token.nil?
      headers[:authorization] = "Bearer #{access_token}" 
    end

    json_obj = JSON.generate(payload)
    response = RestClient::Request.new({
      method: :post,
      url: url,
      payload: json_obj,
      headers: { :accept => :json, content_type: :json }
    }).execute do |response, request, result|
      case response.code
      when 400
        [ :error, JSON.parse(response.to_str) ]
      when 200
        [ :success, JSON.parse(response.to_str) ]
      else
        fail "Invalid response #{response.to_str} received."
      end
    end
  rescue RestClient::Exception => e
    Rails.logger.error("error: #{e.message} response: #{e.response}")
    add_error("error: #{e.message} response: #{e.response}")
  end
end