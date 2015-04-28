class ActivitySessionsController < ApplicationController
  def show
    @activity_session = ActivitySession.find_by_uid!(params[:id])
    puts 'activity session : '
    puts @activity_session.to_json
    @activity = @activity_session.activity
  end
end
