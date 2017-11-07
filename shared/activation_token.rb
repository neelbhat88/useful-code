require "jwt"

class ActivationToken
  def self.issue(args)
    payload = {email: args[:email]}

    expires = (Time.zone.now + 1.hour).to_i
    payload = payload.merge(exp: expires)

    ERB::Util.url_encode(JWT.encode(payload, nil, "none"))
  end

  def self.decode(token)
    JWT.decode(token, nil, false).first
  rescue JWT::ExpiredSignature, JWT::DecodeError
    nil
  end
end
