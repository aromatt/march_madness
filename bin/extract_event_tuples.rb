#!/usr/bin/env ruby
require 'json'

# Expects in stdin event lines, i.e. `cat data/playbyplay_*.tsv | ./bin/extract_event_tuples.rb`
# Outputs line-delimited JSON, one object per team.
# Each team object is an aggregation of events (foul, made_layup, etc) as well as 2-tuple
# and 3-tuple sequences of events (i_steal_i_made_layup) -- prefix 'i' means "this team" and
# prefix 'u' means "the opposing team."
# Each team object has this format:
# {
#   "team": <team_id>,
#   "tuples": {
#     <event_tuple_name>: <count>,
#     ...
#   }
# }

events = {
  missed_jumper: {
    regex: /missed (Jumper|Two Point Tip Shot)/,
    posession: true},
  missed_layup: {regex: /missed Layup/, posession: true},
  missed_dunk: {regex: /missed Dunk/, posession: true},
  missed_3pt: {regex: /missed Three Point Jumper/, posession: true},
  missed_ft: {regex: /missed Free Throw/, posession: true},

  made_jumper: {regex: /made (Jumper|Two Point Tip Shot)/,
    posession: true, points: 2},
  made_layup: {regex: /made Layup/, posession: true, points: 2},
  made_dunk: {regex: /made Dunk/, posession: true, points: 2},
  made_3pt: {regex: /made Three Point Jumper/, posession: true,
    points: 3},
  made_ft: {regex: /made Free Throw/, posession: true, points: 1},

  turnover: {regex: /Turnover/, posession: true},
  steal: {regex: /Steal/, posession: true, follows: :turnover},
  block: {regex: /Block/, posession: false},

  timeout: {regex: /Timeout/},
  foul: {regex: /Foul on/i},
  ejected: {regex: /Ejected/i, skip: true},

  deadball_rebound: {regex: /Deadball Team Rebound/, skip: true},
  off_rebound: {regex: /Offensive Rebound/, posession: true},
  def_rebound: {regex: /Defensive Rebound/, posession: true},
  jump_ball: {regex: /(Jump Ball|alternating possession)/i,
    posession: true},
}

agg = Hash.new { |h, team| h[team] = Hash.new { |h, event| h[event] = 0 } }

count = 0
last_event = nil
last_team = nil
last_event_1 = nil
last_team_1 = nil
unique_events = Hash.new { |h, event| h[event] = 0 }

ARGF.readlines.each do |line|
  action, new_score, team, time = line.split("\t")
  team = team.to_i
  event, _ = events.find {|name, event| event[:regex] =~ action}

  if event
    agg[team][event] += 1
    unique_events[event] += 1
    if last_event && last_team
      double_event = "#{last_team == team ? 'i' : 'u' }_#{last_event}_i_#{event}"
      agg[team][double_event] += 1
      unique_events[double_event] += 1
      if last_event_1 && last_team_1
        triple_event = "#{last_team_1 == team ? 'i' : 'u' }_#{last_event_1}_" + double_event
        agg[team][triple_event] += 1
        unique_events[triple_event] += 1
      end
    end
    #$stderr.puts count if count % 100_000 == 0
    last_event_1 = last_event
    last_team_1 = last_team
    last_event = event
    last_team = team
    count += 1
  end
end

agg.each_pair do |team, tuples|
  team_tuples = { team: team, tuples: tuples }
  puts team_tuples.to_json
end

$stderr.puts "#{count} total events"
$stderr.puts "#{unique_events.count} unique events"
$stderr.puts unique_events
               .sort { |a,b| a[1] <=> b[1] }
               .map { |k, v| "#{v}: #{k}" }
               .join("\n")
