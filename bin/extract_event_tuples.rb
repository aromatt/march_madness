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

# Consider a memory of events: [ current, previous, 2 ago, 3 ago, ... ]
# Use this array to specify tuples you want in your output.
# 0: current, 1: previous, ...
TUPLE_SPEC = [
  [0],
  [0, 1],
  [0, 1, 2],
]

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

def get_prefix(team, cell)
  team == cell[:acting_team] ? 'i' : 'u'
end

tuples = Hash.new { |h, team| h[team] = Hash.new { |h, event| h[event] = 0 } }
unique_events = Hash.new { |h, event| h[event] = 0 }

count = 0
mem_size = TUPLE_SPEC.map(&:max).max + 1
ARGV.each do |file|
  teams = {}
  memory = []

  File.open(file, 'r') do |f|
    lines = f.readlines

    # TODO Hack need to determine both teams before iterating over lines.
    # Skip file unless we have two teams (sometimes they are missing)
    lines.each do |line|
      team = line.split("\t")[2].to_i
      next unless team > 0
      teams[team] = 1
      break if teams.keys.count == 2
    end
    break if teams.keys.count < 2

    lines.each do |line|
      action, new_score, acting_team, time = line.split("\t")
      acting_team = acting_team.to_i
      next unless acting_team > 0
      event, _ = events.find { |name, ev| ev[:regex] =~ action }
      if event
        count += 1
        memory.unshift({ acting_team: acting_team, event: event })
        memory.pop if memory.count > mem_size
        teams.keys.each do |team|
          TUPLE_SPEC.each do |spec|
            next unless memory[spec.max]
            tuple = memory.values_at(*spec)
                          .reverse
                          .map { |c| "#{get_prefix(team, c)}_#{c[:event]}" }
                          .join "_"
            tuples[team][tuple] += 1
            unique_events[tuple] += 1
          end
        end
      end
    end
  end
end

tuples.each_pair do |team, tuples|
  team_tuples = { team: team, tuples: tuples }
  puts team_tuples.to_json
end

$stderr.puts "#{count} total events"
$stderr.puts "#{unique_events.count} unique events"
$stderr.puts unique_events.sort { |a,b| a[1] <=> b[1] }
                          .map { |k, v| "#{v}: #{k}" }
                          .join("\n")
