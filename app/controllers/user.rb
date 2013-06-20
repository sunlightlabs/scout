post "/user/:user_id/:tag/follow" do
  requires_login

  user, tag = load_user_and_tag
  halt 404 if tag.private?
  halt 500 if user == current_user # no!

  interest = Interest.for_tag current_user, user, tag
  interest.save! if interest.new_record?

  json 200, {
    interest_id: interest.id.to_s
  }
end

delete "/user/:user_id/:tag/unfollow" do
  requires_login

  user, tag = load_user_and_tag
  halt 404 if tag.private?

  interest = Interest.for_tag current_user, user, tag
  interest.destroy unless interest.new_record?

  status 200
end


get "/user/:user_id/:tag" do
  # temporary workaround to ensure it doesn't matter what order controllers get loaded in
  pass if params[:tag]['.']

  user, tag = load_user_and_tag

  if tag.private? and (user != current_user)
    halt 404 and return
  end

  interest = Interest.for_tag current_user, user, tag

  other_public_tags = user.tags.where(public: true, _id: {"$ne" => tag._id}).to_a

  erb :"account/tag", locals: {
    tag: tag,
    user: user,
    interest: interest,
    interests: tag.interests,
    other_public_tags: other_public_tags,
    edit: (user == current_user)
  }
end

helpers do

  def load_user_and_tag
    unless user = load_user
      halt 404
    end

    unless tag = user.tags.where(:name => Tag.deslugify(params[:tag])).first
      halt 404
    end

    [user, tag]
  end

end