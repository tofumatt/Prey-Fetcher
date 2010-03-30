# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  
  include Twitter::Login::Helpers
  helper :all # include all helpers, all the time
  helper_method :twitter_user, :twitter_logout
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  filter_parameter_logging :prowl_api_key, :consumer_key, :consumer_secret, :access_key, :access_secret
  
  protected
  
  def check_login
    if twitter_user.nil?
      flash[:error] = "Sorry, but you aren't currently logged in.<br /> You have to sign in to access that part of the site."
      redirect_to(:root)
    else
      @user = User.create_user_from_twitter(twitter_user, session)
    end
  end
  
  # Rescue exceptions with custom error pages in production
  unless ActionController::Base.consider_all_requests_local
    rescue_from Exception, :with => :render_error # Generic error (500, etc.)
    rescue_from ActionController::InvalidAuthenticityToken, :with => :render_csrf
    rescue_from ActiveRecord::RecordNotFound, :with => :render_not_found
    rescue_from ActionController::RoutingError, :with => :render_not_found
    rescue_from ActionController::UnknownController, :with => :render_not_found
    rescue_from ActionController::UnknownAction, :with => :render_not_found
  end
  
  def render_csrf(exception)
    log_error(exception)
    
    @title = "Cross-Site Request Attempt!"
    render :template => "/errors/csrf.html.erb", :status => 403
  end
  
  def render_error(exception)
    log_error(exception)
    
    @title = "Bad Server, Bad!"
    render :template => "/errors/500.html.erb", :status => 500
  end
  
  def render_not_found(exception)
    log_error(exception)
    
    @title = "Page Not Found"
    render :template => "/errors/404.html.erb", :status => 404
  end
  
  # private
  # 
  # def log_error(exception)
  #   super
  #   
  #   require "prowl"
  #   Prowl.add(
  #     :application => APPNAME,
  #     :providerkey => PROWL_PROVIDER_KEY,
  #     :apikey => "",
  #     :priority => 2,
  #     :event => "Exception Raised!",
  #     :description => "An exception was raised at http://preyfetcher.com. You better check it out."
  #   )
  # end
  
end
