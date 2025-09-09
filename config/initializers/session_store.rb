Rails.application.config.session_store :active_record_store,
  key: '_monemusic_session',
  domain: Rails.env.production? ? '.monemusic.com' : :all,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax