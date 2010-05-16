ActionController::Routing::Routes.draw do |map|
  map.connect '/account', :controller => 'users', :action => 'show', :conditions => { :method => :get }
  map.connect '/account', :controller => 'users', :action => 'delete', :conditions => { :method => :delete }
  map.connect '/account/confirm_delete', :controller => 'users', :action => 'confirm_delete'
  map.connect '/account/settings', :controller => 'users', :action => 'update', :conditions => { :method => :put }
  map.connect '/account/settings', :controller => 'users', :action => 'settings'
  
  map.connect '/faq', :controller => 'staticactions', :action => 'faq'
  map.connect '/privacy', :controller => 'staticactions', :action => 'privacy'
  map.connect '/logout', :controller => 'users', :action => 'logout'

  map.root :controller => 'staticactions', :action => 'index'
end
