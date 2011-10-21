module Utils
  
  # If it's a full timestamp with hours and minutes and everything, store that
  # Otherwise, if it's just a day, store the day with a date of noon UTC
  # So that it's the same date everywhere
  def self.govtrack_time_for(timestamp)
    if timestamp =~ /:/
      Time.xmlschema timestamp
    else
      noon_utc_for timestamp
    end
  end
  
  # given a timestamp of the form "2011-02-18", return noon UTC on that day
  def self.noon_utc_for(timestamp)
    time = timestamp.is_a?(String) ? Time.parse(timestamp) : timestamp
    time.getutc + (12-time.getutc.hour).hours
  end
  
  # e.g. 2009 & 2010 -> 111th session, 2011 & 2012 -> 112th session
  def self.current_session
    session_for_year Time.now.year
  end
  
  def self.session_for_year(year)
    ((year + 1) / 2) - 894
  end
  
  def self.strip_unicode(string)
    old_kcode = $KCODE
    $KCODE = "u"
    result = string.mb_chars.strip.to_s
    $KCODE = old_kcode
    result
  end
  
  # map govtrack type to RTC type
  def self.bill_type_for(govtrack_type)
    {
      :h => 'hr',
      :hr => 'hres',
      :hj => 'hjres',
      :hc => 'hcres',
      :s => 's',
      :sr => 'sres',
      :sj => 'sjres',
      :sc => 'scres'
    }[govtrack_type.to_sym]
  end
  
  # map RTC type to GovTrack type
  def self.govtrack_type_for(bill_type)
    {
      'hr' => 'h',
      'hres' => 'hr',
      'hjres' => 'hj',
      'hcres' => 'hc',
      's' => 's',
      'sres' => 'sr',
      'sjres' => 'sj',
      'scres' => 'sc'
    }[bill_type.to_s]
  end
  
  # adapted from http://www.gpoaccess.gov/bills/glossary.html
  def self.bill_version_name_for(version_code)
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
    }[version_code]
  end
  
  def self.constant_vote_keys
    ["Yea", "Nay", "Not Voting", "Present"]
  end
  
  def self.vote_breakdown_for(voters)
    breakdown = {:total => {}, :party => {}}
    
    voters.each do|bioguide_id, voter|      
      party = voter[:voter]['party']
      vote = voter[:vote]
      
      breakdown[:party][party] ||= {}
      breakdown[:party][party][vote] ||= 0
      breakdown[:total][vote] ||= 0
      
      breakdown[:party][party][vote] += 1
      breakdown[:total][vote] += 1
    end
    
    parties = breakdown[:party].keys
    votes = (breakdown[:total].keys + constant_vote_keys).uniq
    votes.each do |vote|
      breakdown[:total][vote] ||= 0
      parties.each do |party|
        breakdown[:party][party][vote] ||= 0
      end
    end
    
    breakdown
  end
  
  
  # Used when processing roll call votes the first time.
  # "passage" will also reliably get set in the second half of votes_archive,
  # when it goes back over each bill and looks at its passage votes.
  def self.vote_type_for(roll_type, question)
    case roll_type
    
    # senate only
    when /cloture/i 
      "cloture"
      
    # senate only
    when /^On the Nomination$/i
      "nomination"
    
    when /^Guilty or Not Guilty/i
      "impeachment"
    
    when /^On the Resolution of Ratification/i
      "treaty"
    
    when /^On (?:the )?Motion to Recommit/i
      "recommit"
      
    # common
    when /^On Passage/i
      "passage"
      
    # house
    when /^On Motion to Concur/i, /^On Motion to Suspend the Rules and (Agree|Concur|Pass)/i, /^Suspend (?:the )?Rules and (Agree|Concur)/i,
      "passage"
    
    # house
    when /^On Agreeing to the Resolution/i, /^On Agreeing to the Concurrent Resolution/i, /^On Agreeing to the Conference Report/i
      "passage"
      
    # senate
    when /^On the Joint Resolution/i, /^On the Concurrent Resolution/i, /^On the Resolution/i
      "passage"
    
    # house only
    when /^Call of the House$/i
      "quorum"
    
    # house only
    when /^Election of the Speaker$/i
      "leadership"
    
    # various procedural things (and various unstandardized vote desc's that will fall through the cracks)
    else
      "other"
      
    end
  end
  
  def self.bill_from(bill_id)
    type, number, session, code, chamber = bill_fields_from bill_id
    
    bill = Bill.new :bill_id => bill_id
    bill.attributes = {
      :bill_type => type,
      :number => number,
      :session => session,
      :code => code,
      :chamber => chamber
    }
    
    bill
  end
  
  def self.bill_fields_from(bill_id)
    type = bill_id.gsub /[^a-z]/, ''
    number = bill_id.match(/[a-z]+(\d+)-/)[1].to_i
    session = bill_id.match(/-(\d+)$/)[1].to_i
    
    code = "#{type}#{number}"
    chamber = {'h' => 'house', 's' => 'senate'}[type.first.downcase]
    
    [type, number, session, code, chamber]
  end
  
  def self.amendment_from(amendment_id)
    chamber = {'h' => 'house', 's' => 'senate'}[amendment_id.gsub(/[^a-z]/, '')]
    number = amendment_id.match(/[a-z]+(\d+)-/)[1].to_i
    session = amendment_id.match(/-(\d+)$/)[1].to_i
    
    amendment = Amendment.new :amendment_id => amendment_id
    amendment.attributes = {
      :chamber => chamber,
      :number => number,
      :session => session
    }
    
    amendment
  end
  
  def self.format_bill_code(bill_type, number)
    {
      "hres" => "H. Res.",
      "hjres" => "H. Joint Res.",
      "hcres" => "H. Con. Res.",
      "hr" => "H.R.",
      "s" => "S.",
      "sres" => "S. Res.",
      "sjres" => "S. Joint Res.",
      "scres" => "S. Con. Res."
    }[bill_type] + " #{number}"
  end
  
  # basic fields and common fetching of them for redundant data
  
  def self.legislator_fields
    [
      :govtrack_id, :bioguide_id,
      :title, :first_name, :nickname, :last_name, :name_suffix, 
      :state, :party, :chamber, :district
    ]
  end
  
  def self.bill_fields
    Bill.basic_fields
  end
  
  def self.amendment_fields
    Amendment.basic_fields
  end
  
  def self.committee_fields
    [:name, :chamber, :committee_id]
  end
  
  def self.document_for(document, fields)
    attributes = document.attributes.dup
    allowed_keys = fields.map {|f| f.to_s}
    
    # for some reason, the 'sort' here causes more keys to get filtered out than without it
    # without the 'sort', it is broken. I do not know why.
    attributes.keys.sort.each {|key| attributes.delete(key) unless allowed_keys.include?(key)}
    
    attributes
  end
  
  def self.legislator_for(legislator)
    document_for legislator, legislator_fields
  end
  
  def self.amendment_for(amendment)
    document_for amendment, amendment_fields
  end
  
  def self.committee_for(committee)
    document_for committee, committee_fields
  end
  
  # usually referenced in absence of an actual bill object
  def self.bill_for(bill_id)
    if bill_id.is_a?(Bill)
      document_for bill_id, bill_fields
    else
      if bill = Bill.where(:bill_id => bill_id).only(bill_fields).first
        document_for bill, bill_fields
      else
        nil
      end
    end
  end
  
  # known discrepancies between us and GovTrack
  def self.committee_id_for(govtrack_id)
    govtrack_id
  end
  
  def self.bill_ids_for(text, session)
    matches = text.scan(/((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.?)*\s?\d+)/i).map {|r| r.first}.uniq.compact
    matches = matches.map {|code| bill_code_to_id code, session}
    matches.uniq
  end
    
  def self.bill_code_to_id(code, session)
    "#{code.gsub(/con/i, "c").tr(" ", "").tr('.', '').downcase}-#{session}"
  end
end