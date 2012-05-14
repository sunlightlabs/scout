# group management:

# creating, updating groups
# adding an interest to a group
# removing a subscription from a group


post "/groups" do
  requires_login

  group = current_user.groups.new params[:group]

  if group.save
    pane = partial "account/groups", :engine => :erb, :locals => {:groups => current_user.groups}
    json 200, {
      :group_id => group.id.to_s,
      :groups_pane => pane
    }
  else
    json 500, {
      :errors => group.errors.full_messages
    }
  end
end