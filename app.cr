require "kemal"
require "crest"

WD = File.dirname( Process.executable_path.to_s )

ENV["PORT"] ||= "3000"

["GRANDLYON_GATEWAY_KEY", "GRANDLYON_LOGIN_URL", "GRANDLYON_USERINFO_URL"].each do |key|
  unless ENV.keys.includes?( key )
    puts "Usage: "
    puts "GRANDLYON_GATEWAY_KEY=\"yourKey\" GRANDLYON_LOGIN_URL=\"url\" GRANDLYON_USERINFO_URL=\"url\" ./app"

    exit( 1 )
  end
end

# kemal routes below
get "/" do |env|
  env.response.content_type = "text/html"

  error_message = ""
  render( "views/index.ecr" )
end

post "/login" do |env|
  login = env.params.body["login"]
  password = env.params.body["password"]

  begin
    response_auth = Crest.post( ENV["GRANDLYON_LOGIN_URL"],
                                headers: { "Content-Type" => "application/x-www-form-urlencoded",
                                           "Authorization" => "Basic #{ENV["GRANDLYON_GATEWAY_KEY"]}" },
                                payload: "scope=openid&grant_type=password&username=#{login}&password=#{password}",
                                logging: true )

    auth = JSON.parse( response_auth.body )
    response_info = Crest.get( ENV["GRANDLYON_USERINFO_URL"],
                               headers: { "Authorization" => "Bearer #{auth["access_token"]}" },
                               logging: true )

    user_info = JSON.parse( response_info.body )
  rescue Crest::BadRequest
    error_message = "Erreur lors de l'authentification."
    render( "views/index.ecr" )
  end
end

Kemal.run( ENV["PORT"].to_i )
