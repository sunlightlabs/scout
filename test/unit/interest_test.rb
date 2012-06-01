require './test/test_helper'

class InterestTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods


  def test_search_interest_deserialization
    user = create :user
    user2 = create :user

    query = "environment"
    query2 = "foia"

    # create a bunch of interests of different types,
    # ensure that at each step we didn't look up an existing one
    i1 = Interest.for_search user, "all", query
    assert i1.new_record?
    assert_equal user, i1.user
    assert_equal query, i1.in
    assert_equal query, i1.data['query']
    assert_equal ['query'], i1.data.keys
    assert_equal "search", i1.interest_type
    assert_equal "all", i1.search_type
    assert i1.save

    i2 = Interest.for_search user, "federal_bills", query
    assert_equal "federal_bills", i2.search_type
    assert i2.new_record?
    assert i2.save

    i3 = Interest.for_search user, "federal_bills", query2
    assert i3.new_record?
    assert i3.save

    i4 = Interest.for_search user2, "federal_bills", query2
    assert i4.new_record?
    assert i4.save

    i5 = Interest.for_search user, "speeches", query, {'state' => 'CA'}
    assert i5.new_record?
    assert_equal 'CA', i5.data['state']
    assert_equal ['query', 'state'].sort, i5.data.keys.sort
    assert i5.save

    i6 = Interest.for_search user, "speeches", query, {'state' => 'CA', 'party' => 'R'}
    assert i6.new_record?
    assert i6.save


    # now, test that the lookup works okay and matches correctly
    i7 = Interest.for_search user, "speeches", query, {'state' => 'CA'}
    assert !i7.new_record?
    assert_equal i5.id, i7.id

    i8 = Interest.for_search user2, "speeches", query, {'state' => 'CA'}
    assert i8.new_record?
    assert_equal user2, i8.user

    i9 = Interest.for_search user, "federal_bills", query2
    assert !i9.new_record?
    assert_equal i3.id, i9.id

    i10 = Interest.for_search user, "speeches", query, {'state' => 'CA', 'party' => 'R'}
    assert !i10.new_record?
    assert_equal i6.id, i10.id


    # add a filter to i6, it is no longer the same interest
    assert_nil i1.data['chamber']
    i6.data['chamber'] = "house"
    assert i6.save
    assert_equal "house", i6.reload.data['chamber']

    i11 = Interest.for_search user, "speeches", query, {'state' => 'CA', 'party' => 'R'}
    assert i11.new_record?
  end

  def test_item_interest_deserialization
    user = create :user
    user2 = create :user

    item_id = "hr4192-112"
    item_type = "bill"
    item2_id = "s4567-112"
    item2_type = "bill"
    item3_id = item_id.dup # let's just pretend
    item3_type = "state_bill"

    i1 = Interest.for_item user, item_id, item_type
    assert i1.new_record?
    assert_equal user, i1.user
    assert_equal item_id, i1.in
    assert_equal "item", i1.interest_type
    assert_equal item_type, i1.item_type
    assert_equal [], i1.data.keys
    assert i1.save

    i2 = Interest.for_item user, item2_id, item2_type
    assert i2.new_record?
    assert_equal item2_id, i2.in
    assert_equal item2_type, i2.item_type
    assert i2.save

    i3 = Interest.for_item user, item3_id, item3_type
    assert i3.new_record?
    assert_equal item3_id, i3.in
    assert_equal item3_type, i3.item_type
    assert i3.save

    i4 = Interest.for_item user2, item_id, item_type
    assert i4.new_record?
    assert_equal user2, i4.user
    assert i4.save


    i5 = Interest.for_item user, item_id, item_type
    assert !i5.new_record?
    assert_equal i1.id, i5.id

    # add a piece of data to i1, it does not affect the lookup
    assert_nil i1.data['chamber']
    i1.data['chamber'] = "house"
    assert i1.save
    assert_equal "house", i1.reload.data['chamber']

    i6 = Interest.for_item user, item_id, item_type
    assert !i6.new_record?
    assert_equal i1.id, i6.id
  end

  def test_feed_interest_deserialization
    user = create :user
    user2 = create :user

    url = "http://example.com/1"
    url2 = "http://example.com/2"

    i1 = Interest.for_feed user, url
    assert i1.new_record?
    assert_equal url, i1.in
    assert_equal user, i1.user
    assert_equal "feed", i1.interest_type
    assert_equal [], i1.data.keys
    assert i1.save

    i2 = Interest.for_feed user, url2
    assert i2.new_record?
    assert i2.save

    i3 = Interest.for_feed user2, url
    assert i3.new_record?
    assert_equal user2, i3.user
    assert i3.save


    i4 = Interest.for_feed user, url
    assert !i4.new_record?
    assert_equal i1.id, i4.id


    # add some extra data to i1, it does *not* change the lookup
    assert_nil i1.data['original_title']
    i1.data['original_title'] = "new title"
    assert i1.save
    assert_equal "new title", i1.reload.data['original_title']

    i5 = Interest.for_feed user, url
    assert !i5.new_record?
    assert_equal i1.id, i5.id
  end
  
end