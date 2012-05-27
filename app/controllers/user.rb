get "/user/:user_id/:tag" do
  unless user = load_user
    halt 404 and return
  end

  unless tag = user.tags.where(:name => Tag.deslugify(params[:tag])).first
    halt 404 and return
  end

  erb :"account/tag", :locals => {
    :tag => tag,
    :user => user
  }
end