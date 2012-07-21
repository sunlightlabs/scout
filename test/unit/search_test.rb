# encoding: utf-8

require './test/test_helper'

# test out search helper functions (extractions)

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_extract_usc
    assert_equal "5_usc_552", Search.check_usc("5 U.S.C. 552")
    assert_equal "5_usc_552", Search.check_usc("5 USC 552")
    assert_equal "5_usc_552", Search.check_usc("5 U.S.C. § 552")
    assert_equal "5_usc_552", Search.check_usc("    5 U.S.C. 552 ")

    # can't have another term next to it
    assert_equal nil, Search.check_usc("science 5 U.S.C. 552")
    assert_equal nil, Search.check_usc("5 U.S.C. 552 technology")
    assert_equal nil, Search.check_usc("5 U.S.C. john 552")

    # subsections
    assert_equal "6_usc_123_bb_102", Search.check_usc("6 USC 123(bb)(102)")
    assert_equal "6_usc_123_11111", Search.check_usc("6 USC 123(11111)")
    assert_equal "50_usc_404o-1_a", Search.check_usc("50 U.S.C. 404o-1(a)")


    # pattern 2 (section X of title Y)
    assert_equal "5_usc_552", Search.check_usc("section 552 of title 5")
    assert_equal "5_usc_552", Search.check_usc("    section 552 of title 5 ")

    # can't have another term next to it
    assert_equal nil, Search.check_usc("science section 552 of title 5")
    assert_equal nil, Search.check_usc("section 552 of title 5 technology")
    assert_equal nil, Search.check_usc("section john 552 of title 5")

    # subsections
    assert_equal "6_usc_123_bb_102", Search.check_usc("section 123(bb)(102) of title 6")
    assert_equal "6_usc_123_11111", Search.check_usc("section 123(11111) of title 6")
    assert_equal "50_usc_404o-1_a", Search.check_usc("section 404o-1(a) of title 50")
  end

end