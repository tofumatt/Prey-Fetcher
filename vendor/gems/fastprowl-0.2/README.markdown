# FastProwl
## Ruby Prowl library that uses libcurl-multi for parallel requests

*FastProwl* is a Ruby library for interacting with the Prowl API **using Typhoeus** (a libcurl-multi interface written in Ruby). It is inspired heavily by [August Lilleaas](http://august.lilleaas.net/)'s [ruby-prowl](http://github.com/augustl/ruby-prowl) library (the class method `FastProwl.add()` still works if you include this library instead).

*FastProwl* lets you queue up many Prowl API requests then make them concurrently, which is handy if you make a bunch of requests in quick succession. It was developed for [Prey Fetcher](http://preyfetcher.com), which sends too many notifications requests to wait on blocking HTTP calls.

Please fork away and send me a pull request if you think you can make it better or whatnot.

## Installation

Assuming you have [Gemcutter](http://gemcutter.org/) setup as a gem source, install like any other Ruby gem:

	gem install fastprowl

If you don't already have [Gemcutter](http://gemcutter.org/) setup as one of your gem sources, install FastProwl with the following command:

	gem install fastprowl --source http://gemcutter.org/

## Usage

Pretty simple -- you can send single notifications without bothering with queuing and all that by using the class method `FastProwl.add()`:

	FastProwl.add(
      :apikey => 'valid_api_key',
      :application => 'Car Repair Shop',
      :event => 'Your car is now ready!',
      :description => 'We had to replace a part. Bring your credit card.'
    )

As mentioned, this is the same as using [ruby-prowl](http://github.com/augustl/ruby-prowl). It will return `true` on success; `false` otherwise.

If you want to send concurrent requests (presumably you do), create an instance object and use the `add()` method to queue up your requests. When all of your requests are ready, use the `run()` method to send all of your queued notifications:

	# You can put any attributes you want in the constructor
	# to save repeatly supplying them when you call add()
	prowl = FastProwl.new(
	  :application => 'Car Repair Shop',
	  :event => 'Your car has been ready for ages!',
	  :description => 'Hurry up! Bring your credit card!'
	)
	
	users.each do |user|
	  prowl.add(
	    :apikey => user.prowl_apikey,
      )
	end
	
	prowl.run

You get the idea.

## License

This program is free software; it is distributed under an [MIT-style License](http://fosspass.org/license/mit?author=Matthew+Riley+MacPherson&year=2010).

---

Copyright (c) 2010 [Matthew Riley MacPherson](http://lonelyvegan.com).