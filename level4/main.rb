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
            "id" => project["id"],
            "total_days" => (to - from).to_i + 1,
            "holidays" => days_count["holidays"],
            "weekend_days" => days_count["weekend"],
            "workdays" => days_count["work"],
            "feasibility" => total_availability >= project["effort_days"],
            "from" => project["since"],
            "to" => project["until"],
            "effort_days" => project["effort_days"],
        }
    end
}

feasible_projects = availabilities_hash["availabilities"].select { |project| project["feasibility"] }

from = Date.strptime(feasible_projects.map { |p| p["from"]}.min, dateformat)
to = Date.strptime(feasible_projects.map { |p| p["to"]}.max, dateformat)

holidays = Holidays.between(from, to, locale).map { |h| h[:date] } + data_hash["local_holidays"].map { |h| Date.strptime(h["day"]) }

project_status = feasible_projects.reduce( [] ) { |arr, project| 
    arr += [{
        "id" => project["id"],
        "effort_days" => project["effort_days"],
        "assigned_days" => 0,
        "from" => project["from"],
        "to" => project["to"],
    }]
    arr   
}

schedule = (from..to).reduce({}) { |obj, day|

    is_weekend = isWeekend(day)
    is_holiday = (holidays.include? day)

    if !is_weekend && !is_holiday

        data_hash["developers"].each { |dev| 

            active_projects = project_status.select { |project|
                prj_from = Date.strptime(project["from"], dateformat)
                prj_to = Date.strptime(project["to"], dateformat)
                (day >= prj_from) && (day <= prj_to) && project["assigned_days"] < project["effort_days"]
            }

            if active_projects.length > 0 && !isBirthday(day, Date.strptime(dev["birthday"], dateformat))
                
                # differenza fra i giorni che ho per concludere il progetto e quelli che mancano
                urgent_project = active_projects.sort_by { |prj| 
                    prj_to = Date.strptime(prj["to"], dateformat)
                    time_available = prj_to - day
                    time_required = prj["effort_days"] - prj["assigned_days"]
                    time_available - time_required
                }[0]

                if !obj[day.to_s]
                    obj[day.to_s] = []
                end

                urgent_project["assigned_days"] += 1

                obj[day.to_s] += [{
                    "dev" => dev["id"],
                    "prj" => urgent_project["id"],
                    "status" => Marshal.load(Marshal.dump(project_status))
                }]

            end
        }
    end
    
    obj
}

# checks

schedule.each { |day, assignments| 
    puts "#{day} " + assignments.map { |a| "dev #{a["dev"]} prj #{a["prj"]}" }.join(" ")
}

puts project_status

begin
    File.write(output_filename, JSON.pretty_generate(schedule))
rescue => e
    puts "error writing #{output_filename} : #{e.message}"
end