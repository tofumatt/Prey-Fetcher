# Custom settings used by Prey Fetcher
ADMIN_EMAILS = %w(foo@bar.com) # People to be notified on Exception
APPNAME = 'Prey Fetcher'
MAX_CONCURRENCY = 50 # FastProwl concurrency
OAUTH_SETTINGS = {
	'callback' => '',
	'consumer_key' => '',
	'consumer_secret' => ''
}
PROWL_PROVIDER_KEY = '' # Optional, but very handy
SESSION_SECRET = ''
SYSADMIN_PROWL_KEY = '' # Optional; notifies you by Prowl on Exception
TWITTER_CREDENTIALS = { # Required to access the Streaming API. Should be whitelisted
  :username => '',
  :password => ''
}
USER_AGENT = "#{APPNAME} (http://preyfetcher.com)"
