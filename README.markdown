# Prey Fetcher
## Push your tweets to your iPhone

Prey Fetcher is a _free and open-source service_ that automatically **pushes new mentions & direct messages to your iPhone**. It requires [Prowl](http://prowl.weks.net), an iPhone Growl client. Prey Fetcher uses Twitter's REST and Streaming APIs to deliver fast DM notifications and _instant_ notifications of mentions.

## Requirements

Prey Fetcher is a Rails 2.3 app, so you'll need Ruby, Rails, and some gems to run your own version of it. You'll also need to generate your own OAuth tokens and put them in your own config file. Prey Fetcher is not currently 100% tested to run without certain settings (like the Prowl Provider Key) or even on other servers, though it runs fine in development mode on my local machines. **Being able to run your own Prey Fetcher instance, should you choose to do so, is a goal and will be coming in a future release.**

## Contributing

If you're a Ruby/Rails coder and think you can make Prey Fetcher better or add a cool feature, let me know! If you plan on writing a feature for [preyfetcher.com](http://preyfetcher.com), you might want to check the issues queue to make sure it's not already being worked on and would actually be included in the site.

Once you've added a feature/made fixes, assuming you made a fork, just send me a pull request and I'll take a look at it. If there's an issue related to whatever you pushed, update that ticket as well.

# License
This program is free software; it is distributed under the [GNU Affero General Public License, Version 3](http://www.gnu.org/licenses/agpl-3.0.html).

This means that you can distribute/use modified and/or unmodified versions however you like, but you have to make the source code available if you modify it and run it on your own server somewhere. I'm fine with multiple Prey Fetcher instances (even if other ones cost money), but the goal is to get any improvements to the code base back to everyone, including me (so I can use them at [preyfetcher.com](http://preyfetcher.com), if I want).

---

Copyright (c) 2010 [Matthew Riley MacPherson](http://lonelyvegan.com).
