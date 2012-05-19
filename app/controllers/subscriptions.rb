# delete any interest, by ID (from the subscriptions management page)
delete '/interest/:id' do
  requires_login
  
  if interest = current_user.interests.find(params[:id])
    interest.destroy
    halt 200
  else
    halt 404
  end
end


# update any interest, by ID (from the subscriptions management page)
put '/interest/:id' do
  requires_login

  unless interest = current_user.interests.find(params[:id])
    halt 404 and return false
  end

  if params[:interest]['notifications']
    interest.notifications = params[:interest]['notifications']
  end

  if params[:interest]['tags']
    interest.new_tags = params[:interest]['tags']
  end

  if interest.save
    pane = partial "account/tags", :engine => :erb, :locals => {:tags => current_user.interests.distinct(:tags)}
    json 200, {
      :tags => interest.tags,
      :notifications => interest.notifications,
      :tags_pane => pane
    }
  else
    halt 500
  end
end