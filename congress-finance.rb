require 'opensecrets'
require 'httparty'
require 'pry'
require 'pp'

def get_candidate_doners(osid)
  begin
    candidate = OpenSecrets::Candidate.new('906370639fd00fbd5dc306467eb4006e')
    return candidate.contributors({cid: osid})["response"]["contributors"]["contributor"]
  rescue
    return []
  end
end

def get_candidate_industries(osid)
  begin
    candidate = OpenSecrets::Candidate.new('906370639fd00fbd5dc306467eb4006e')
    return candidate.industries({cid: osid})["response"]["industries"]["industry"]
  rescue
    return []
  end
end


def get_vote_direction(vote_voter)
  yea = vote_voter["option"]["key"] == "+"
  nay = vote_voter["option"]["key"] == "-"

  vote_direction = 0
  if yea
    vote_direction = 1
  elsif nay
    vote_direction = -1
  end

  return vote_direction
end

def get_vote_voters(vote_id)
  return HTTParty.get("https://www.govtrack.us/api/v2/vote_voter?vote=#{vote_id}").parsed_response["objects"]
end

def get_votes(bill_id)
  return HTTParty.get("https://www.govtrack.us/api/v2/vote?related_bill=#{bill_id}").parsed_response["objects"]
end

def get_bills(bill_name)
  url = "https://www.govtrack.us/api/v2/bill?q=#{bill_name}&limit=3"
  puts url
  return HTTParty.get(url).parsed_response["objects"]
end


#pp member.get_legislators({id: "CA"})["response"]["legislator"].first

puts "What's the bill you're searching for?"
bill_name = gets.chomp.downcase.gsub!(' ', '%20')


get_bills(bill_name).each do |bill|
  puts "Processing #{bill["title"]}..."
  
  doner_contributions = {}
  industry_contributions = {}
  get_votes(bill["id"]).each do |vote|
    get_vote_voters(vote["id"]).each do |vote_voter|
      vote_direction = get_vote_direction(vote_voter)
      osid = vote_voter["person"]["osid"]

      get_candidate_doners(osid).each do |doner|
        doner_contributions[doner["org_name"]] ||= 0
        doner_contributions[doner["org_name"]] += vote_direction * doner["total"].to_f
      end

      get_candidate_industries(osid).each do |industry|
        industry_contributions[industry["industry_name"]] ||= 0
        industry_contributions[industry["industry_name"]] += vote_direction * industry["total"].to_f
      end
    end
  end

  puts "Doners:"
  pp doner_contributions.sort_by{ |key, value| -value }
  puts "Industries:"
  pp industry_contributions.sort_by{ |key, value| -value }
  #We want osid for OpenSecrets
end

