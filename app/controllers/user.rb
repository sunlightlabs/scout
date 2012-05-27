get "/user/:user_id/:tag" do

  unless user = load_user
    halt 404 and return
  end

  unless tag = user.tags.where(:name => Tag.deslugify(params[:tag])).first
    halt 404 and return
  end

  if tag.private? and (user != current_user)
    halt 404 and return
  end

  erb :"account/tag", :locals => {
    :tag => tag,
    :user => user,
    :interests => tag.interests,
    :edit => (user == current_user)
  }
end