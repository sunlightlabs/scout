module Subscriptions::Helpers
  # bill display helpers
  
  def short_date(time)
    time.strftime "%m-%d-%Y"
  end
  
  def very_short_date(time)
    time.strftime "%m/%d"
  end
  
  def bill_code(type, number)
    "#{bill_type type} #{number}"
  end
  
  # standardized in accordance with http://www.gpoaccess.gov/bills/glossary.html
  def bill_type(short)
    {
      "hr" => "H.R.",
      "hres" => "H.Res.",
      "hjres" => "H.J.Res.",
      "hcres" => "H.C.Res.",
      "s" => "S.",
      "sres" => "S.Res.",
      "sjres" => "S.J.Res.",
      "scres" => "S.C.Res."
    }[short]
  end
  
  def bill_highlight(item)
    highlighting = item.data['search']['highlight']
    field = highlighting.keys.sort_by {|k| highlight_priority k}.first
    
    "<dt>From #{highlight_field field}:</dt>\n<dd>#{highlighting[field]}</dd>"
  end
  
  def govtrack_type(bill_type)
    {
      "hr" => "h",
      "hres" => "hr",
      "hjres" => "hj",
      "hcres" => "hc",
      "s" => "s",
      "sres" => "sr",
      "sjres" => "sj",
      "scres" => "sc"
    }[bill_type]
  end
  
  # most are fine, just alter the con res's
  def thomas_type(bill_type)
    {
      "hcres" => "hconres",
      "scres" => "sconres"
    }[bill_type] || bill_type
  end
  
  def opencongress_url(item)
    bill = item.data['bill']
    id = "#{bill['session']}-#{govtrack_type bill['bill_type']}#{bill['number']}"
    "http://www.opencongress.org/bill/#{id}/show"
  end
  
  def govtrack_url(item)
    bill = item.data['bill']
    id = "#{govtrack_type bill['bill_type']}#{bill['session']}-#{bill['number']}"
    "http://www.govtrack.us/congress/bill.xpd?bill=#{id}"
  end
  
  def thomas_url(item)
    bill = item.data['bill']
    id = "#{bill['session']}#{thomas_type bill['bill_type']}#{bill['number']}"
    "http://hdl.loc.gov/loc.uscongress/legislation.#{id}"
  end
  
  def highlight_field(field)
    {
      "full_text" => "the full text",
      "bill__summary" => "the CRS summary",
      "bill__official_title" => "the official title",
      "bill__short_title" => "the shorthand title",
      "bill__popular_title" => "the common parlance",
      "bill__keywords" => "the tagged subjects"
    }[field]
  end
  
  def highlight_priority(field)
    {
      "bill__summary" => 1,
      "full_text" => 2,
      "bill__keywords" => 3,
      "bill__official_title" => 4,
      "bill__short_title" => 5,
      "bill__popular_title" => 6
    }[field]
  end
  
  # adapted from http://www.gpoaccess.gov/bills/glossary.html
  def bill_version(code)
    {
      'ash' => "Additional Sponsors House",
      'ath' => "Agreed to House",
      'ats' => "Agreed to Senate",
      'cdh' => "Committee Discharged House",
      'cds' => "Committee Discharged Senate",
      'cph' => "Considered and Passed House",
      'cps' => "Considered and Passed Senate",
      'eah' => "Engrossed Amendment House",
      'eas' => "Engrossed Amendment Senate",
      'eh' => "Engrossed in House",
      'ehr' => "Engrossed in House-Reprint",
      'eh_s' => "Engrossed in House (No.) Star Print [*]",
      'enr' => "Enrolled Bill",
      'es' => "Engrossed in Senate",
      'esr' => "Engrossed in Senate-Reprint",
      'es_s' => "Engrossed in Senate (No.) Star Print",
      'fah' => "Failed Amendment House",
      'fps' => "Failed Passage Senate",
      'hdh' => "Held at Desk House",
      'hds' => "Held at Desk Senate",
      'ih' => "Introduced in House",
      'ihr' => "Introduced in House-Reprint",
      'ih_s' => "Introduced in House (No.) Star Print",
      'iph' => "Indefinitely Postponed in House",
      'ips' => "Indefinitely Postponed in Senate",
      'is' => "Introduced in Senate",
      'isr' => "Introduced in Senate-Reprint",
      'is_s' => "Introduced in Senate (No.) Star Print",
      'lth' => "Laid on Table in House",
      'lts' => "Laid on Table in Senate",
      'oph' => "Ordered to be Printed House",
      'ops' => "Ordered to be Printed Senate",
      'pch' => "Placed on Calendar House",
      'pcs' => "Placed on Calendar Senate",
      'pp' => "Public Print",
      'rah' => "Referred w/Amendments House",
      'ras' => "Referred w/Amendments Senate",
      'rch' => "Reference Change House",
      'rcs' => "Reference Change Senate",
      'rdh' => "Received in House",
      'rds' => "Received in Senate",
      're' => "Reprint of an Amendment",
      'reah' => "Re-engrossed Amendment House",
      'renr' => "Re-enrolled",
      'res' => "Re-engrossed Amendment Senate",
      'rfh' => "Referred in House",
      'rfhr' => "Referred in House-Reprint",
      'rfh_s' => "Referred in House (No.) Star Print",
      'rfs' => "Referred in Senate",
      'rfsr' => "Referred in Senate-Reprint",
      'rfs_s' => "Referred in Senate (No.) Star Print",
      'rh' => "Reported in House",
      'rhr' => "Reported in House-Reprint",
      'rh_s' => "Reported in House (No.) Star Print",
      'rih' => "Referral Instructions House",
      'ris' => "Referral Instructions Senate",
      'rs' => "Reported in Senate",
      'rsr' => "Reported in Senate-Reprint",
      'rs_s' => "Reported in Senate (No.) Star Print",
      'rth' => "Referred to Committee House",
      'rts' => "Referred to Committee Senate",
      'sas' => "Additional Sponsors Senate",
      'sc' => "Sponsor Change House",
      's_p' => "Star (No.) Print of an Amendment"
    }[code]
  end
  
end