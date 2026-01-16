# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and throttling
# Protects public endpoints from abuse

class Rack::Attack
  # Throttle all POST requests to public forms by IP
  # Allow 5 requests per minute per IP
  throttle("public_forms/ip", limit: 5, period: 60.seconds) do |req|
    if req.post? && public_form_path?(req.path)
      req.ip
    end
  end

  # Stricter hourly limit for form submissions (prevents queue flooding)
  # Allow 20 requests per hour per IP
  throttle("form_submissions/ip/hour", limit: 20, period: 1.hour) do |req|
    if req.post? && public_form_path?(req.path)
      req.ip
    end
  end

  # Throttle by email address to prevent abuse of specific forms
  # Allow 3 submissions per email per hour
  throttle("form_submissions/email", limit: 3, period: 1.hour) do |req|
    if req.post? && public_form_path?(req.path)
      # Extract email from form params
      req.params["sender_email"] || req.params["email"] || req.params.dig("profile", "email")
    end
  end

  # Safelist localhost in development
  safelist("allow-localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip
  end unless Rails.env.production?

  # Custom throttled response
  self.throttled_responder = lambda do |request|
    [
      429,
      { "Content-Type" => "text/html", "Retry-After" => "60" },
      ["Too many requests. Please try again later."]
    ]
  end

  # Helper method to identify public form paths
  def self.public_form_path?(path)
    public_paths = [
      "/contacts",
      "/subscribe",
      "/guest_applications"
    ]

    # Check for exact matches
    return true if public_paths.include?(path)

    # Check for guest_messages under profiles (e.g., /profiles/123/guest_messages)
    return true if path.match?(%r{^/profiles/\d+/guest_messages$})

    false
  end
end
