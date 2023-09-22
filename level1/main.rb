require "json"
require "holidays"

def isWeekend(date)
    return date.saturday? || date.sunday?
end

input_filename = 'data.json' 
dateformat = "%Y-%m-%d"
locale = :it

begin
    file = File.read input_filename
rescue Errno::ENOENT
    puts  + "#{input_filename} does not exist"
rescue => e
    puts "error accessing #{input_filename} : #{e.message}"
end

unless file 
    exit
end

data_hash = JSON.parse file
output_hash = {}

data_hash["periods"].each do |period|
    from = Date.strptime(period["since"], dateformat)
    to = Date.strptime(period["until"], dateformat)

    holidays = Holidays.between(from, to, locale).map { |h| h[:date] }

    days = (from..to)

    # check different object notation
    days_count = days.reduce({ "weekend" => 0, "work" => 0, "holidays" => 0 }) do |obj, day|

        is_weekend = isWeekend(day)
        
        if (holidays.include? day) && !is_weekend
            obj["holidays"] += 1
        elsif is_weekend
            obj["weekend"] += 1
        else 
            obj["work"] += 1
        end
        obj # no "return"!
    end

    availability = {
        period_id: period["id"],
        total_days: days.size(),
        holidays: days_count["holidays"],
        weekend_days: days_count["weekend"],
        workdays: days_count["work"]
    }

    puts availability
end