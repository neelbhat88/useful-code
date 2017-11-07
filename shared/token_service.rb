require "jwt"

class TokenService
  ALGORITHM = "HS256".freeze

  def self.issue(args)
    payload = {user_id: args[:user_id], email: args[:email], domain: args[:domain]}
    JWT.encode(payload, auth_secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, auth_secret, true, algorithm: ALGORITHM).first
  end

  def self.auth_secret
    ENV["TOKEN_AUTH_SECRET"]
  end
end
