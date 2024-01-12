require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require('time')
require('date')

def clean_zipcode(zipcode)
  zipcode.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    return "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist? 'output'
  file_name = "output/thanks_#{id}.html"
  File.open(file_name, 'w') do |f|
    f.puts form_letter
  end
end

def clean_phone_number(phone_number)
  cleaned_phone_number = phone_number.gsub(/\D/, "")
  size = cleaned_phone_number.size
  return "invalid phone number" if size > 11 || size < 10 || (size == 11 && cleaned_phone_number[0] != "1")
  cleaned_phone_number = cleaned_phone_number[1..10] if size == 11
  cleaned_phone_number.insert(3, "-").insert(7, "-")
end

def find_time(string)
  t = Time.strptime(string, "%m/%d/%Y %k:%M")
end

def save_peak_hour(peak_hour_array)
  File.open('peak_hour.txt', "w") do |f|
    peak_hour_array.each do |hour, guess_number|
      f.puts "At #{hour}, #{guess_number} visited"
    end
  end
end

def save_text_content(content, file_name)
  File.open("#{file_name}.txt", "w") do |f|
    f.puts content
  end
end

def update_peak_hour(peak_hour, hour)
  if peak_hour[hour] == nil
    peak_hour[hour] = 1
  else 
    peak_hour[hour] += 1
  end
end

def update_week_day(week_day_list, time)
  d = time.wday
  day_name = Date::DAYNAMES[d]
  week_day_list[day_name] = week_day_list[day_name] == nil ? 1 : week_day_list[day_name] + 1
end

data = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol
) if File.exist? "event_attendees.csv"

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
peak_hour = {}
phone_list = []
week_day_list = {}

data.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode].to_s)
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  phone_number = clean_phone_number(row[:homephone])
  phone_list.push phone_number
  
  time = find_time(row[:regdate])
  update_peak_hour(peak_hour, time.hour)   
  update_week_day(week_day_list, time)
end
week_day_list = week_day_list.sort_by { |key, value| -value }.to_h
peak_hour_array = peak_hour.sort_by { |key, value| -value }
save_peak_hour(peak_hour_array)
save_text_content(phone_list, "phone_list")
save_text_content(week_day_list, "peak_day")
p week_day_list
