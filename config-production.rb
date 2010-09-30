# These values override defaults set in prey_fetcher.rb.
# These are only loaded in production.
PREYFETCHER_CONFIG_PRODUCTION_RB = {
  # Regular app config
  :app_asset_domain => 'static.preyfetcher.com',
  :app_domain => 'preyfetcher.com',
  :app_name => 'Prey Fetcher',
  :app_prowl_provider_key => '',
  
  # Assign your own database info here
  :db_adapter => 'mysql',
  :db_host => 'localhost',
  :db_database => 'preyfetcher',
  :db_username => 'preyfetcher',
  :db_password => '',
  
  # Twitter configs
  :twitter_consumer_key => '',
  :twitter_consumer_secret => '',
  :twitter_access_key => '',
  :twitter_access_secret => '',
  :twitter_site_stream_size => 100
}
