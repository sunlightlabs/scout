get "/interest/:interest_id.rss" do

  unless interest = Interest.find(params[:interest_id])
    halt 404 and return
  end

  items = SeenItem.where(interest_id: interest.id).desc :date

  rss_for "interest", items, interest: interest
end

get "/user/:user_id/:tag.rss" do
  name = Tag.deslugify params[:tag]
  unless (user = load_user) and (tag = user.tags.where(name: name).first)
    halt 404 and return
  end

  interest_ids = tag.interests.only(:_id).map &:_id
  items = SeenItem.where(interest_id: {"$in" => interest_ids}).desc :date

  rss_for "tag", items, tag: tag
end

helpers do

  def rss_for(view, items, locals = {})
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > 200000000
    per_page = 100

    items = items.skip(per_page * (page - 1)).limit(per_page)

    headers["Content-Type"] = "application/rss+xml"
    erb :"rss/#{view}", layout: false, locals: {
      items: items,
      url: request.url
    }.merge(locals)
  end

end