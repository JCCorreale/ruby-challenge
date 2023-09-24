require "json"
require "holidays"

def isWeekend(date)
    return date.saturday? || date.sunday?
end

def isBirthday(date, birthday)
    (date.month() == birthday.month()) && (date.day() == birthday.day())
end

example_output_filename = "output.json"
output_filename = "my_output.json"
input_filename = 'data.json' 
dateformat = "%Y-%m-%d"
locale = :it

begin
    file = File.read input_filename
rescue Errno::ENOENT
    puts  + "#{input_filename} does not exist"
rescue => e
    puts "error reading #{input_filename} : #{e.message}"
end

unless file 
    exit
end

data_hash = JSON.parse file
output_hash = {}

availabilities_hash = { "availabilities" => data_hash["periods"].flat_map do |period|
        from = Date.strptime(period["since"], dateformat)
        to = Date.strptime(period["until"], dateformat)

        holidays = Holidays.between(from, to, locale).map { |h| h[:date] } + data_hash["local_holidays"].map { |h| Date.strptime(h["day"]) }

        data_hash["developers"].map do |dev| 

            days_count = (from..to).reduce({ "weekend" => 0, "work" => 0, "holidays" => 0 }) do |obj, day|

                is_weekend = isWeekend(day)
                is_holiday = (holidays.include? day)

                birthday = Date.strptime(dev["birthday"], dateformat)
                is_birthday = isBirthday(day, birthday)

                if is_weekend
                    obj["weekend"] += 1
                elsif is_holiday || is_birthday
                    obj["holidays"] += 1
                else
                    obj["work"] += 1
                end
                obj
            end

            {
                "developer_id" => dev["id"],
                "period_id" => period["id"],
                "total_days" => (to - from).to_i + 1,
                "holidays" => days_count["holidays"],
                "weekend_days" => days_count["weekend"],
                "workdays" => days_count["work"]
            }

            end
        end
    }


begin
    File.write(output_filename, JSON.pretty_generate(availabilities_hash))
rescue => e
    puts "error writing #{output_filename} : #{e.message}"
end

# double check
example_output = JSON.parse File.read example_output_filename
if availabilities_hash == example_output
    puts "OK"
else
    puts "KO"
end