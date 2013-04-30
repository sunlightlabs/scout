put '/account/tag/:name/description' do
  requires_login

  name = params[:name].strip.downcase
  unless tag = current_user.tags.where(name: Tag.deslugify(name)).first
    halt 404 and return
  end

  tag.description = params[:description]

  if tag.save
    description = partial "account/description", engine: "erb", locals: {
      user: current_user, tag: tag
    }

    json 200, {
      description_pane: description
    }
  else
    halt 500
  end
end

put '/account/tag/:name/public' do
  requires_login

  name = params[:name].strip.downcase
  unless tag = current_user.tags.where(name: Tag.deslugify(name)).first
    halt 404 and return
  end

  tag.public = params[:public]
  tag.save!

  redirect tag_path(current_user, tag)
end

delete "/account/tags" do
  requires_login

  names = (params[:names] || []).map {|name| Tag.deslugify name}

  names.each do |name|
    if tag = current_user.tags.where(name: name).first
      tag.destroy
    end
  end

  redirect "/account/subscriptions"
end