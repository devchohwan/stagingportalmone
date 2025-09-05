Rails.application.config.session_store :cookie_store, 
  key: '_monemusic_session',
  domain: :all,
  tld_length: 2,
  same_site: :lax,
  secure: false,
  httponly: true