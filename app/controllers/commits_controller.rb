class CommitsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
  # GET /changelog
  def index
    @title = 'Changelog'
    @commits = Commit.all(:limit => 5, :order => 'timestamp DESC')
  end

  # POST /changelog
  def create
    payload = JSON.parse(params['payload'])
    
    return unless payload['repository']['name'] == 'Prey-Fetcher' && payload['repository']['url'] == 'http://github.com/tofumatt/Prey-Fetcher'
    
    payload['commits'].each do |commit|
      commit['sha'] = commit['id']
      commit['author_name'] = commit['author']['name']
      commit['author_email'] = commit['author']['email']
      ['added', 'author', 'id', 'modified', 'removed'].each do |key|
        commit.delete key
      end
      
      Commit.create(commit)
    end
    
    render :json => {:result => 'It worked!'}
  end
end
