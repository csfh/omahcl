# Rails would name the cookie after the application module, an old internal name.
Rails.application.config.session_store :cookie_store, key: "_session"
