class Event
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name
  field :description
  field :data, type: Hash

  def self.unsubscribe!(interest)
    create!(
      name: "Remove alert", 
      description: "#{interest.user.contact} from #{interest.in}", 
      data: interest.attributes.dup
    )
  end
end