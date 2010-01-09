# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#   
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

# Add in the notifications from the old site (when notifications
# were just a count without an attached user record)
(1..5).each do
  # None of the old notifications are tied to a user,
  # but it's nice for them to be part of the new count,
  # as there were over 60k
  Notification.create(:twitter_user_id => 0)
end