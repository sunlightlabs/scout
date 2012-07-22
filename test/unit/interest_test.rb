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
    i1 = Interest.for_search user, "all", query, query, 
      {'query' => query, 'query_type' => 'simple'}
    assert i1.new_record?
    assert_equal user, i1.user
    assert_equal query, i1.in
    assert_equal query, i1.data['query']
    assert_equal 'simple', i1.data['query_type']
    assert_equal ['query', 'query_type'].sort, i1.data.keys.sort
    assert_equal "search", i1.interest_type
    assert_equal "all", i1.search_type
    assert i1.save

    # can override query and make it different than 'in'
    i1a = Interest.for_search user, "all", query, query, 
      {'query' => query2, 'query_type' => 'simple'}
    assert_equal "all", i1a.search_type
    assert_equal query, i1a.in
    assert_equal query2, i1a.data['query']
    assert i1a.new_record?
    assert i1a.save, i1a.errors.inspect

    # can even override query with nil, that's fine
    i1b = Interest.for_search user, "all", query, query, 
      {'query' => nil, 'query_type' => 'simple'}
    assert_equal "all", i1b.search_type
    assert_equal query, i1b.in
    assert_equal nil, i1b.data['query']
    assert i1b.new_record?
    assert i1b.save, i1b.errors.inspect

    # but don't allow nil in's or original_in's
    i1c = Interest.for_search user, "all", nil, query, 
      {'query' => query, 'query_type' => 'simple'}
    assert_nil i1c

    i1d = Interest.for_search user, "all", query, nil,
      {'query' => query, 'query_type' => 'simple'}
    assert_nil i1d

    # don't allow missing query or query_type fields
    i1e = Interest.for_search user, "all", query, query,
      {'query_type' => 'simple'}
    assert_nil i1e

    i1f = Interest.for_search user, "all", query, query, 
      {'query' => query}
    assert_nil i1f
    
    i2 = Interest.for_search user, "federal_bills", query, query, 
      {'query' => query, 'query_type' => 'simple'}
    assert_equal "federal_bills", i2.search_type
    assert i2.new_record?
    assert i2.save

    i3 = Interest.for_search user, "federal_bills", query2, query2, 
      {'query' => query2, 'query_type' => 'simple'}
    assert i3.new_record?
    assert i3.save

    i4 = Interest.for_search user2, "federal_bills", query2, query2, 
      {'query' => query2, 'query_type' => 'simple'}
    assert i4.new_record?
    assert i4.save

    i5 = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA'}
    assert i5.new_record?
    assert_equal 'CA', i5.data['state']
    assert_equal ['query', 'query_type', 'state'].sort, i5.data.keys.sort
    assert i5.save

    i6 = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA', 'party' => 'R'}
    assert i6.new_record?
    assert i6.save


    # now, test that the lookup works okay and matches correctly
    i7 = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA'}
    assert !i7.new_record?
    assert_equal i5.id, i7.id

    i7a = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA', 'query_type' => 'simple'}
    assert !i7a.new_record?
    assert_equal i5.id, i7a.id

    i7b = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'advanced', 'state' => 'CA'}
    assert i7b.new_record?

    i7c = Interest.for_search nil, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA'}
    assert i7c.new_record?

    i8 = Interest.for_search user2, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA'}
    assert i8.new_record?
    assert_equal user2, i8.user

    i9 = Interest.for_search user, "federal_bills", query2, query2,
      {'query' => query2, 'query_type' => 'simple'}
    assert !i9.new_record?
    assert_equal i3.id, i9.id

    i10 = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA', 'party' => 'R'}
    assert !i10.new_record?
    assert_equal i6.id, i10.id


    # add a filter to i6, it is no longer the same interest
    assert_nil i1.data['chamber']
    i6.data['chamber'] = "house"
    assert i6.save
    assert_equal "house", i6.reload.data['chamber']


    i11 = Interest.for_search user, "speeches", query, query, 
      {'query' => query, 'query_type' => 'simple', 'state' => 'CA', 'party' => 'R'}
    assert i11.new_record?


    # testing that uniqueness constraint ignores 'in' for search results
    cite1 = "5 usc 552"
    cite2 = "section 552 of title 5"
    citation_id = "5_usc_552"
    
    c1 = Interest.for_search user, "all", citation_id, cite1,
      {'query' => nil, 'query_type' => 'simple', 
       'citation_id' => citation_id, 'citation_type' => 'usc'}
    assert c1.new_record?
    assert_equal citation_id, c1.in
    assert_equal cite1, c1.original_in
    assert_equal citation_id, c1.data['citation_id']
    assert c1.data.has_key?('query')
    assert_nil c1.data['query']
    assert c1.save

    # user has an interest for the same citation under a different search string
    c2 = Interest.for_search user, "all", citation_id, cite2,
      {'query' => nil, 'query_type' => 'simple', 
       'citation_id' => citation_id, 'citation_type' => 'usc'}

    # it should have located c1, with c1's citation
    assert !c2.new_record?
    assert_equal citation_id, c2.in
    assert_equal cite1, c2.original_in
    assert_equal citation_id, c2.data['citation_id']
    assert c2.data.has_key?('query')
    assert_nil c2.data['query']

    # data hash is same as c1, but the interest.in didn't resolve to the same thing,
    # nor is the original_in the same.
    # should still look up c1, we are not using interest.in to resolve 
    c2a = Interest.for_search user, "all", citation_id.succ, cite2,
      {'query' => nil, 'query_type' => 'simple', 
       'citation_id' => citation_id, 'citation_type' => 'usc'}

    # it should have located c1, with c1's in and original_in
    assert !c2a.new_record?
    assert_equal citation_id, c2a.in
    assert_equal cite1, c2a.original_in
    assert_equal citation_id, c2a.data['citation_id']
    assert c2a.data.has_key?('query')
    assert_nil c2a.data['query']
    
    c3 = Interest.for_search nil, "all", citation_id, cite1, 
      {'query' => nil, 'query_type' => 'simple', 
       'citation_id' => citation_id, 'citation_type' => 'usc'}

    assert c3.new_record?
    assert_equal citation_id, c3.in
    assert_equal cite1, c3.original_in
    assert_equal citation_id, c3.data['citation_id']
    assert c3.data.has_key?('query')
    assert_nil c3.data['query']
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

    i5a = Interest.for_item nil, item_id, item_type
    assert i5a.new_record?

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

    i4a = Interest.for_feed nil, url
    assert i4a.new_record?


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