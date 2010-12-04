# ![Image of the Prey Fetcher zebra (yes, it's a zebra!)](https://github.com/tofumatt/Prey-Fetcher/raw/master/public/images/prey-fetcher.png) Prey Fetcher #

## Push your tweets to your iPhone ##

Prey Fetcher is a _free and open source service_ that pushes new tweets and direct messages to your iPhone, iPod Touch, or iPad. It requires [Prowl](http://prowl.weks.net), an iPhone Growl client. Prey Fetcher uses Twitter's REST and Streaming APIs to deliver fast list notifications and _instant_ notifications of DMs and mentions.

## Requirements ##

Prey Fetcher is a Sinatra web app/service, so you'll need Ruby, Sinatra, and some gems to run your own version of it. Prey Fetcher uses [Bundler](http://gembundler.com/), so you should be able to setup the gems/resolve dependencies as long as you have Bundler 1.0 installed. You'll also need to generate your own OAuth tokens and put them in your own config file. You should be able to run your own Prey Fetcher instance, should you choose to do so. **If you are running your own instance, please let me know how it's going.**

## Contributing ##

If you're a Ruby coder and think you can make Prey Fetcher better or add a cool feature, let me know! If you plan on writing a feature for [preyfetcher.com](http://preyfetcher.com), you might want to check the issues queue to make sure it's not already being worked on and would actually be included in the site.

Once you've added a feature/made fixes, assuming you made a fork, just send me a pull request and I'll take a look at it. If there's an issue related to whatever you pushed, update that ticket as well.

## Donating ##

Prey Fetcher is, and will always be, a totally free service for users. I run it on [its own VPS](http://www.linode.com) out of my own pocket. The server is not super expensive (about $20/month) and I'm happy to have the service running, though I welcome donations to keep the project going, server resources available, and to motivate me to actually work on the project.

Prey Fetcher does basically everything _I_ want it to do already, but I want to add features for others. Because I work on it in my spare time and most new features will require more API polling and thus more resources, donations are greatly appreciated.

You can [donate money via PayPal](http://pledgie.com/campaigns/10696) (via [Pledgie](http://pledgie.com/)). Or you can donate some time (by coding), or resources (if you want to host Prey Fetcher for free).

# License #
This program is free software; it is distributed under an [MIT License](http://github.com/tofumatt/Prey-Fetcher/blob/master/LICENSE.txt).

---

Copyright (c) 2010 [Matthew Riley MacPherson](http://lonelyvegan.com).
