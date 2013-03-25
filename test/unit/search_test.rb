# encoding: utf-8

require './test/test_helper'

# test out search helper functions (extractions)

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_extract_usc
    assert_equal "5_usc_552", Search.usc_check("5 U.S.C. 552")
    assert_equal "5_usc_552", Search.usc_check("5 USC 552")
    assert_equal "5_usc_552", Search.usc_check("5 U.S.C. § 552")
    assert_equal "5_usc_552", Search.usc_check("    5 U.S.C. 552 ")

    # can't have another term next to it
    assert_equal nil, Search.usc_check("science 5 U.S.C. 552")
    assert_equal nil, Search.usc_check("5 U.S.C. 552 technology")
    assert_equal nil, Search.usc_check("5 U.S.C. john 552")

    # subsections
    assert_equal "6_usc_123_bb_102", Search.usc_check("6 USC 123(bb)(102)")
    assert_equal "6_usc_123_11111", Search.usc_check("6 USC 123(11111)")
    assert_equal "50_usc_404o-1_a", Search.usc_check("50 U.S.C. 404o-1(a)")


    # pattern 2 (section X of title Y)
    assert_equal "5_usc_552", Search.usc_check("section 552 of title 5")
    assert_equal "5_usc_552", Search.usc_check("    section 552 of title 5 ")

    # can't have another term next to it
    assert_equal nil, Search.usc_check("science section 552 of title 5")
    assert_equal nil, Search.usc_check("section 552 of title 5 technology")
    assert_equal nil, Search.usc_check("section john 552 of title 5")

    # subsections
    assert_equal "6_usc_123_bb_102", Search.usc_check("section 123(bb)(102) of title 6")
    assert_equal "6_usc_123_11111", Search.usc_check("section 123(11111) of title 6")
    assert_equal "50_usc_404o-1_a", Search.usc_check("section 404o-1(a) of title 50")
  end

  def test_state_bill_detect
    assert_equal "SB 112", Search.state_bill_for("SB 112")
    assert_equal "SB 112", Search.state_bill_for(" SB   112   ")
  end

end