
# controller must be loaded last, because it's got the wildcard routes

get "/:user_id/:tag" do
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

helpers do

  def load_user
    user_id = params[:user_id].strip
    if user = User.where(:username => user_id).first
      user
    elsif BSON::ObjectId.legal?(user_id)
      User.find user_id
    else
      nil
    end
  end
end