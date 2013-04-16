# encoding: utf-8

require './test/test_helper'

# test out search helper functions (extractions)

class SearchTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_extract_usc
    assert_equal "usc/5/552", Search.usc_check("5 U.S.C. 552")
    assert_equal "usc/5/552", Search.usc_check("5 USC 552")
    assert_equal "usc/5/552", Search.usc_check("5 U.S.C. § 552")
    assert_equal "usc/5/552", Search.usc_check("    5 U.S.C. 552 ")

    # can't have another term next to it
    assert_equal nil, Search.usc_check("science 5 U.S.C. 552")
    assert_equal nil, Search.usc_check("5 U.S.C. 552 technology")
    assert_equal nil, Search.usc_check("5 U.S.C. john 552")

    # subsections
    assert_equal "usc/6/123/bb/102", Search.usc_check("6 USC 123(bb)(102)")
    assert_equal "usc/6/123/11111", Search.usc_check("6 USC 123(11111)")
    assert_equal "usc/50/404o-1/a", Search.usc_check("50 U.S.C. 404o-1(a)")


    # pattern 2 (section X of title Y)
    assert_equal "usc/5/552", Search.usc_check("section 552 of title 5")
    assert_equal "usc/5/552", Search.usc_check("    section 552 of title 5 ")

    # can't have another term next to it
    assert_equal nil, Search.usc_check("science section 552 of title 5")
    assert_equal nil, Search.usc_check("section 552 of title 5 technology")
    assert_equal nil, Search.usc_check("section john 552 of title 5")

    # subsections
    assert_equal "usc/6/123/bb/102", Search.usc_check("section 123(bb)(102) of title 6")
    assert_equal "usc/6/123/11111", Search.usc_check("section 123(11111) of title 6")
    assert_equal "usc/50/404o-1/a", Search.usc_check("section 404o-1(a) of title 50")
  end

  def test_state_bill_detect
    assert_equal "SB 112", Search.state_bill_for("SB 112")
    assert_equal "SB 112", Search.state_bill_for(" SB   112   ")
    assert_equal "SB 112", Search.state_bill_for("S.B. 112")
    assert_equal "SB 112", Search.state_bill_for("S.B 112")
    assert_equal "SB 112", Search.state_bill_for("SB. 112")
    assert_equal "HB 13-1043", Search.state_bill_for("HB. 13-1043")
  end

  def test_federal_bill_detect
    assert_equal ["hr", "3590"], Search.federal_bill_for("H.R. 3590")
    assert_equal ["hr", "3590"], Search.federal_bill_for("HR 3590")
    assert_equal ["hr", "3590"], Search.federal_bill_for("hr3590")
    assert_equal ["hres", "49"], Search.federal_bill_for("  H.res 49   ")
    assert_equal ["sconres", "1"], Search.federal_bill_for("sconres 1")
    assert_equal ["sconres", "1"], Search.federal_bill_for("scres1")
    assert_equal ["s", "74"], Search.federal_bill_for("s 74")
  end

end