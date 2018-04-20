require "base64"
require "openssl/hmac"
require "uri"

require "kemal"
require "crest"

ENV["PORT"] ||= "3000"

unless ARGV.size == 4
  puts "Usage: "
  puts "./app \"sso key\" \"api key\" \"login_url\" \"userinfo_url\""

  exit( 1 )
end

DISCOURSE_SSO_KEY = ARGV[0]
GATEWAY_KEY = ARGV[1]
LOGIN_URL = ARGV[2]
USERINFO_URL = ARGV[3]

def hash_to_payload( hash : Hash ) : String
  hash.map { |key, value| "#{key}=#{value}" }.join( "&" )
end

def payload_to_hash( payload : String) : Hash
  payload.split("&").map { |item| item.split("=") }.to_h
end

def sign_discourse_payload( payload : String, key : String ) : String
  OpenSSL::HMAC.hexdigest(:sha256, key, payload)
end

def check_discourse_payload_signature( payload : String, signature : String, key : String ) : Bool
  sign_discourse_payload( payload, key ) == signature
end

# kemal routes below
get "/" do |env|
  sig = env.params.query["sig"]
  payload = env.params.query["sso"]

  if check_discourse_payload_signature( payload, sig, DISCOURSE_SSO_KEY )
    payload = payload_to_hash( Base64.decode_string( payload ) )

    error_message = ""
    nonce = payload["nonce"]
    return_sso_url = payload["return_sso_url"]
  else
    error_message = "Appel invalide de la part de Discourse."
    nonce = "error"
    return_sso_url = "error"
  end

  env.response.content_type = "text/html"
  render( "views/index.ecr" )
end

post "/login" do |env|
  begin
    response_auth = Crest.post( LOGIN_URL,
                                headers: { "Content-Type" => "application/x-www-form-urlencoded",
                                           "Authorization" => "Basic #{GATEWAY_KEY}" },
                                payload: hash_to_payload( { "scope" => "openid",
                                                            "grant_type" => "password",
                                                            "username" => env.params.body["login"],
                                                            "password" => env.params.body["password"] } ),
                                logging: true )

    auth = JSON.parse( response_auth.body )
    response_info = Crest.get( USERINFO_URL,
                               headers: { "Authorization" => "Bearer #{auth["access_token"]}" },
                               logging: true )

    user_info = JSON.parse( response_info.body )

    discourse_payload = Base64.strict_encode( hash_to_payload( { "nonce" => env.params.body["nonce"],
                                                                 "external_id" => URI.escape( user_info["email"].to_s.split("@").first ),
                                                                 "username" => URI.escape( user_info["email"].to_s.split("@").first ),
                                                                 "email" => URI.escape( user_info["email"].to_s ),
                                                                 "name" => URI.escape( "#{user_info["given_name"]}#{user_info["family_name"]}" ) } ) )
    discourse_payload_signature = sign_discourse_payload( discourse_payload, DISCOURSE_SSO_KEY )

    env.redirect "#{ URI.unescape( env.params.body["return_sso_url"] ) }?sso=#{discourse_payload}&sig=#{discourse_payload_signature}"
  rescue Crest::BadRequest
    error_message = "Erreur lors de l'authentification."
    nonce = "error"
    return_sso_url = "error"

    env.response.content_type = "text/html"
    render( "views/index.ecr" )
  end
end

Kemal.run( ENV["PORT"].to_i )
