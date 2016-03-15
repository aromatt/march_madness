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

SINGLE = true
DOUBLE = true
TRIPLE = true
QUAD =   true
PENT =   true
SIX =    true
SEVEN =  true

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
unique_events = Hash.new { |h, event| h[event] = 0 }

count = 0
ARGV.each do |file|
  teams = {}
  last_event = nil
  last_team = nil
  last_event_1 = nil
  last_team_1 = nil
  last_event_2 = nil
  last_team_2 = nil
  last_event_3 = nil
  last_team_3 = nil
  last_event_4 = nil
  last_team_4 = nil
  last_event_5 = nil
  last_team_5 = nil

  File.open(file, 'r') do |f|
    lines = f.readlines

    # TODO Need to determine both teams before iterating over lines.
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
      event, _ = events.find {|name, event| event[:regex] =~ action}

      if event
        teams.keys.each do |team|
          # 1-tuple
          prefix = (team == acting_team ? 'i' : 'u')
          single_event = "#{prefix}_#{event}"
          if SINGLE
            agg[team][single_event] += 1
            unique_events[single_event] += 1
          end

          # 2-tuple
          if last_event && last_team
            prefix = (team == last_team ? 'i' : 'u')
            double_event = "#{prefix}_#{last_event}_" + single_event
            if DOUBLE
              agg[team][double_event] += 1
              unique_events[double_event] += 1
            end

            # 3-tuple
            if last_event_1 && last_team_1
              prefix = (team == last_team_1 ? 'i' : 'u')
              triple_event = "#{prefix}_#{last_event_1}_" + double_event
              if TRIPLE
                agg[team][triple_event] += 1
                unique_events[triple_event] += 1
              end

              # 4-tuple
              if last_event_2 && last_team_2
                prefix = (team == last_team_2 ? 'i' : 'u')
                quad_event = "#{prefix}_#{last_event_2}_" + triple_event
                if QUAD
                  agg[team][quad_event] += 1
                  unique_events[quad_event] += 1
                end

                # 5-tuple
                if last_event_3 && last_team_3
                  prefix = (team == last_team_3 ? 'i' : 'u')
                  pent_event = "#{prefix}_#{last_event_3}_" + quad_event
                  if PENT
                    agg[team][pent_event] += 1
                    unique_events[pent_event] += 1
                  end

                  # 6-tuple
                  if last_event_4 && last_team_4
                    prefix = (team == last_team_4 ? 'i' : 'u')
                    six_event = "#{prefix}_#{last_event_4}_" + pent_event
                    if SIX
                      agg[team][six_event] += 1
                      unique_events[six_event] += 1
                    end

                    # 7-tuple
                    if last_event_5 && last_team_5
                      prefix = (team == last_team_5 ? 'i' : 'u')
                      seven_event = "#{prefix}_#{last_event_5}_" + six_event
                      if SEVEN
                        agg[team][seven_event] += 1
                        unique_events[seven_event] += 1
                      end
                    end
                  end
                end
              end
            end
          end
        end
        last_event_5 = last_event_4
        last_team_5 = last_team_4
        last_event_4 = last_event_3
        last_team_4 = last_team_3
        last_event_3 = last_event_2
        last_team_3 = last_team_2
        last_event_2 = last_event_1
        last_team_2 = last_team_1
        last_event_1 = last_event
        last_team_1 = last_team
        last_event = event
        last_team = acting_team
        count += 1
      end
    end
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
