class StaticactionsController < ApplicationController
	# GET /
  def index
    @title = 'Open Source Twitter Push Notifications'
  end

  # GET /faq
  def faq
    @title = 'Questions About Prey Fetcher'
  end

	# GET /privacy
  def privacy
    @title = 'Privacy Policy (a.k.a. No Snooping)!'
  end
end
