post "/user/:user_id/:collection/follow" do
  requires_login

  user, collection = load_user_and_collection
  halt 404 if collection.private?
  halt 500 if user == current_user # no!

  interest = Interest.for_tag current_user, user, collection
  interest.save! if interest.new_record?

  json 200, {
    interest_id: interest.id.to_s
  }
end

delete "/user/:user_id/:collection/unfollow" do
  requires_login

  user, collection = load_user_and_collection
  halt 404 if collection.private?

  interest = Interest.for_tag current_user, user, collection
  interest.destroy unless interest.new_record?

  status 200
end


get "/user/:user_id/:collection" do
  # temporary workaround to ensure it doesn't matter what order controllers get loaded in
  pass if params[:collection]['.']

  user, collection = load_user_and_collection

  if collection.private? and (user != current_user)
    halt 404 and return
  end

  interest = Interest.for_tag current_user, user, collection

  # load in users' other shared collections
  other_public_collections = user.tags.where(public: true, _id: {"$ne" => collection._id}).to_a

  # preview of items fetched so far for this collection
  interest_ids = collection.interests.only(:_id).map &:_id
  items = SeenItem.where(interest_id: {"$in" => interest_ids}).desc :date
  items = items.limit(10).to_a

  erb :"account/collection", locals: {
    collection: collection,
    user: user,
    interest: interest,
    interests: collection.interests,
    items: items,
    other_public_collections: other_public_collections,
    edit: (user == current_user)
  }
end

helpers do

  def load_user_and_collection
    unless user = load_user
      halt 404
    end

    unless collection = user.tags.where(name: Tag.deslugify(params[:collection])).first
      halt 404
    end

    [user, collection]
  end

end