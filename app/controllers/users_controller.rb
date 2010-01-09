class UsersController < ApplicationController
  
  # Make sure the current user is logged in via Twitter
  before_filter :check_login
  
  # GET /account
  def show
    @title = "@#{twitter_user.screen_name}'s Account"
    @user = User.find(:first, :conditions => { :twitter_user_id => twitter_user.id })
  end
  
  # GET /account/settings
  def settings
    # This notice will be displayed only once -- when the user is created
    flash[:notice] = %{Please supply your Prowl API Key so we can push tweets to your iPhone/iPod Touch. If you don't have Prowl, you can <a href="http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=320876271&amp;mt=8">buy it on the App Store</a>.} if @user && @user.prowl_api_key.blank?
    
    @title = 'Change Your Notification Settings'
    @user ||= User.find(:first, :conditions => { :twitter_user_id => twitter_user.id })
  end

  # PUT /account/settings
  def update
    @user = User.find(:first, :conditions => { :twitter_user_id => twitter_user.id })
    @title = 'Change Your Notification Settings'
    
    if @user.update_attributes(params[:user])
      flash[:notice] = 'Settings were updated A-OK!'
      redirect_to(:action => :settings)
    else
      render :action => :settings
    end
  end
  
  # GET /account/confirm_delete
  def confirm_delete
    @title = "Delete @#{twitter_user.screen_name}'s Account"
    @user = User.find(:first, :conditions => { :twitter_user_id => twitter_user.id })
  end
  
  # DELETE /account
  def delete
    @user = User.find(:first, :conditions => { :twitter_user_id => twitter_user.id })
    @user.destroy
    twitter_logout
    
    flash[:notice] = "Your account was deleted!<br /> We're sorry to see you go @#{@user.twitter_username}!"
    
    redirect_to(:root)
  end
  
  # GET /logout
  def logout
    # Logout is just a link -- honestly not too worried about remote
    # logout attempts, but try to prevent it a bit by checking the
    # REFERER HTTP header
    if request.env["HTTP_REFERER"].match(/^https?:\/\/#{HOST}\//)
      twitter_logout
      flash[:notice] = 'You are now logged out of Prey Fetcher.<br /> Did you want to <a href="http://twitter.com/logout">log out of Twitter.com too</a>?'
    else
      flash[:alert] = %{Another site (<em class="underline">#{request.env["HTTP_REFERER"].gsub!(/^https?:\/\//, "")}</em>) tried to log you out of preyfetcher.com!<br /> You have to be signed in to Prey Fetcher to logout.}
    end
    
    redirect_to(:root)
  end
  
end
