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

birthdays = data_hash["developers"].map{ |d| Date.strptime(d["birthday"], dateformat) }

availabilities_hash = { "availabilities" => data_hash["projects"].map do |project|
        from = Date.strptime(project["since"], dateformat)
        to = Date.strptime(project["until"], dateformat)

        holidays = Holidays.between(from, to, locale).map { |h| h[:date] } + data_hash["local_holidays"].map { |h| Date.strptime(h["day"]) }

        days_count = (from..to).reduce({ "weekend" => 0, "work" => 0, "holidays" => 0, "availability" => { } }) do |obj, day|

            is_weekend = isWeekend(day)
            is_holiday = (holidays.include? day)

            if is_weekend
                obj["weekend"] += 1
            elsif is_holiday
                obj["holidays"] += 1
            else
                obj["work"] += 1

                data_hash["developers"].each { |dev| 

                    if !obj["availability"].key? dev["id"]
                        obj["availability"][dev["id"]] = 0
                    end

                    birthday = Date.strptime(dev["birthday"], dateformat)
                    is_birthday = isBirthday(day, birthday)

                    if !is_birthday
                        obj["availability"][dev["id"]] += 1
                    end
                }

            end
            obj
        end


        total_availability = days_count["availability"].reduce(0) { |sum, (key, value)| 
            sum += value
        }

        {
            "period_id" => project["id"],
            "total_days" => (to - from).to_i + 1,
            "holidays" => days_count["holidays"],
            "weekend_days" => days_count["weekend"],
            "workdays" => days_count["work"],
            "feasibility" => total_availability >= project["effort_days"]
        }
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