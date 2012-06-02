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

  tags = []
  if params[:interest]['tags']
    halt 500 if interest.tag? # no!
    interest.new_tags = params[:interest]['tags']
    tags = interest.tags.map do |name| 
      current_user.tags.find_or_initialize_by :name => name
    end
  end

  if interest.save
    # should be guaranteed to be safe
    tags.each {|tag| tag.save! if tag.new_record?}

    pane = partial "account/tags", :engine => :erb, :locals => {:tags => current_user.tags}
    json 200, {
      :interest_tags => interest.tags,
      :notifications => interest.notifications,
      :tags_pane => pane
    }
  else
    halt 500
  end
end