put '/account/collection/:name/description' do
  requires_login

  name = params[:name].strip.downcase
  unless collection = current_user.tags.where(name: Tag.deslugify(name)).first
    halt 404 and return
  end

  collection.description = params[:description]

  if collection.save
    description = partial "account/description", engine: "erb", locals: {
      user: current_user, collection: collection
    }

    json 200, {
      description_pane: description
    }
  else
    halt 500
  end
end

put '/account/collection/:name/public' do
  requires_login

  name = params[:name].strip.downcase
  unless collection = current_user.tags.where(name: Tag.deslugify(name)).first
    halt 404 and return
  end

  collection.public = params[:public]
  collection.save!

  redirect Tag.collection_path(current_user, collection)
end

delete "/account/collections" do
  requires_login

  names = (params[:names] || []).map {|name| Tag.deslugify name}

  names.each do |name|
    if collection = current_user.tags.where(name: name).first
      collection.destroy
    end
  end

  redirect "/account/subscriptions"
end