def off_by_one?(winner, search)
  count = 0
  i = 0
  4.times do 
    if search[i] == winner[i]
      count += 1
    end
    i += 1
  end
  count == 3
end

def find_no_cigar(your_number, winning_numbers)
  matches = []
  winning_numbers.each do |winner|
    if off_by_one?(winner, your_number)
      matches << winner
    end
  end
  matches
end

def winning_ticket?(prize)
  if prize.num_tuples.zero?
    false
  else
    true
  end
end 

def extract_winning_numbers(winners)
  winning_numbers = []
  winners.each do |winner|
    winning_numbers.push(winner["winning_number"])
  end
  winning_numbers
end

def convert_array_tickets_to_string(tickets_off_by_one)
  tickets_off_by_one.map! do |ticket|
    "'" + ticket + "'"
  end
  tickets_off_by_one.join(',')
end




