#!/usr/bin/env ruby

require 'json'

procs = ENV['PROCS'].to_i || 16
name = ENV['NAME'] || 'noname'

root = File.expand_path('../..', __FILE__)
script = File.expand_path('bin/extract_event_tuples.rb', root)
exp_dir = File.expand_path("stat/#{name}", root)

if `ls #{exp_dir} 2>/dev/null` != ''
  $stderr.puts "#{exp_dir} already exists"
  exit 1
end
`mkdir -p #{exp_dir}`

threads = []
ARGV.group_by { |file| file.hash % procs }.sort.each do |i, group|
  $stderr.puts "Launching process #{i} with #{group.count} files"
  threads << Thread.new do
    `#{script} #{group.join(" ")} 1>#{exp_dir}/tuples_part_#{i}.json 2>#{exp_dir}/err_part_#{i}`
  end
end

threads.each_with_index.map { |t, i| t.join; $stderr.puts "Process #{i} done" }
$stderr.puts "Merging..."

merged = {}
totals = Hash.new { |h, k| h[k] = 0 }
`ls #{exp_dir}/tuples_part_*.json`.split(' ').each_with_index do |file, i|
  puts "#{File.basename(file)}"
  File.open(file).each do |json_line|
    begin
      team, tuples = JSON.load(json_line).values_at("team", "tuples")
      merged[team] ||= Hash.new { |h, k| h[k] = 0 }
      merged[team].merge!(tuples) { |k, old, new| old + new }
      totals.merge!(tuples) { |k, old, new| old + new }
    rescue JSON::ParserError => e
      $stderr.puts "JSON parse error"
    end
  end
end

File.open(File.expand_path('report.txt', exp_dir), 'w') do |f|
  f.puts "#{totals.values.reduce(&:+)} total events"
  f.puts "#{totals.keys.count} unique events"
  f.puts totals.sort { |a,b| a[1] <=> b[1] }
                .map { |k, v| "#{v}: #{k}" }
                .join("\n")
end

File.open(File.expand_path('tuples.json', exp_dir), 'w') do |f|
  merged.each_pair do |team, tuples|
    team_tuples = { team: team, tuples: tuples }
    f.puts team_tuples.to_json
  end
end
