require './test/test_helper'

class MapTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  # mapping from a given search adapter to the type of item it searches over
  def test_search_adapters_to_item_types
    assert search_adapters.is_a?(Hash)
    assert_equal search_adapters['federal_bills'], 'bill'
    assert_equal search_adapters['state_bills'], 'state_bill'
  end

  # mapping from a given item adapter to the type of item its data is focused on
  def test_item_adapters_to_item_types
    assert item_adapters.is_a?(Hash)
    assert_equal item_adapters['federal_bills_activity'], 'bill'
    assert_equal item_adapters['state_bills_votes'], 'state_bill'
  end

  # mapping from a given item type to the adapters that follow it
  def test_item_types_to_item_adapters
    assert item_types.is_a?(Hash)
    ['bill', 'state_bill'].each do |item_type|
      assert_equal item_types[item_type]['subscriptions'].sort, item_adapters.keys.select {|adapter| item_adapters[adapter] == item_type}.sort
    end
  end

  # mapping from a given item type to the adapter that searches over it
  def test_item_types_to_search_adapter
    assert item_types.is_a?(Hash)
    ['bill', 'state_bill', 'speech', 'regulation', 'document', 'state_legislator'].each do |item_type|
      assert_equal item_types[item_type]['adapter'], search_adapters.keys.find {|adapter| search_adapters[adapter] == item_type}
    end
  end

end