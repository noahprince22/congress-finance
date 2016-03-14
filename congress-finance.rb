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

def get_votes(vote_name, congress, num)
  ret = []

  while (ret.size < num && congress >= 0)
    # Set a high limit so we get everything
    votes = HTTParty.get("https://www.govtrack.us/api/v2/vote?congress=#{congress}&limit=5000").parsed_response["objects"] 

    votes.each do |vote|
      # Check if it's in the vote's question or related bill's title
      related_bill = vote["related_bill"]
      related_bill_title = related_bill ? related_bill["title"] : ""
      question = vote["question"]
      question ||= ""

      # See if it's in any of the vote's titles (these change over time)
      titles = vote["titles"]
      titles ||= []
      has_in_title = false
      titles.each do |title|
        has_in_title = true if title[2].downcase.include?(vote_name)
      end
      
      if question.downcase.include?(vote_name) || related_bill_title.downcase.include?(vote_name) || has_in_title
        ret.push vote

        break if ret.size >= num
      end
    end

    puts "Searching congress \##{congress}"
    congress-=1
  end

  puts "No results found matching #{vote_name}" if congress == 0
  return ret
end

#pp member.get_legislators({id: "CA"})["response"]["legislator"].first

puts "What's the vote you're searching for?"
vote_name = gets.chomp.downcase

puts "Congress to start searching from?"
congress = gets.chomp.to_i

puts "Maximum number of votes to analyse?"
num = gets.chomp.to_i

get_votes(vote_name, congress, num).each do |vote|
  puts "Processing #{vote['question']}..."
  doner_contributions = {}
  industry_contributions = {}
  
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

  def print_top_5(h)
    i = 0
    h.sort_by{ |key, value| -value }.each do |key, value|
      break if i > 5
      puts "#{key}, Weighted Amount: #{value}"
      i+=1
    end
  end

  def print_bottom_5(h)
    i = 0
    h.sort_by{ |key, value| value }.each do |key, value|
      break if i > 5
      puts "#{key}, Weighted Amount: #{value}"
      i+=1
    end
  end

  puts "Top 5 Donors For It:"
  print_top_5(doner_contributions)

  puts "\nTop 5 Donors Against It:"
  print_bottom_5(doner_contributions)

  puts "\nTop 5 Industries For It:"
  print_top_5(industry_contributions)

  puts "\nTop 5 Industries Against It:"
  print_bottom_5(industry_contributions)
end

