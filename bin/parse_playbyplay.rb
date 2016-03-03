#!/usr/bin/env ruby

file = ARGV[0]

raise 'Source file name not given' unless file

contents = File.read(file).force_encoding('ASCII-8bit')
lines = contents.split("\n")

exit 0 if lines.count <= 1

header = lines.shift

team_a_score = 0
team_b_score = 0

events = {
  missed_jumper: {regex: /missed (Jumper|Two Point Tip Shot)/},
  missed_layup: {regex: /missed Layup/},
  missed_dunk: {regex: /missed Dunk/},
  missed_3pt: {regex: /missed Three Point Jumper/},
  missed_ft: {regex: /missed Free Throw/},

  made_jumper: {regex: /made (Jumper|Two Point Tip Shot)/},
  made_layup: {regex: /made Layup/},
  made_dunk: {regex: /made Dunk/},
  made_3pt: {regex: /made Three Point Jumper/},
  made_ft: {regex: /made Free Throw/},

  turnover: {regex: /Turnover/},
  steal: {regex: /Steal/},
  block: {regex: /Block/},

  foul: {regex: /^Foul on/},
  technical_foul: {regex: /Technical Foul on/},
  intentional_foul: {regex: /^Intentional Foul on/},
  flagrant: {regex: /Flagrant/i},
  ejected: {regex: /Ejected/i},

  deadball_rebound: {regex: /Deadball Team Rebound/, skip: true},
  off_rebound: {regex: /Offensive Rebound/},
  def_rebound: {regex: /Defensive Rebound/},
  jump_ball: {regex: /(Jump Ball|alternating possession)/i},
}

combos = [
  [2, 18],
  [3, 18],
  [4, 18],
  [5, 18],
]

current_state = nil
transitions = (0...(events.size)).to_a.map{|i| Hash.new{|h,k| h[k] = 0} }

lines.each do |line|
  score, team_a_action, team_b_action, time = line.split("\t")
  a_score, b_score = score.split("-").map{|t| t.to_i}
  minutes, seconds = time.split(":").map{|t| t.to_i}

  if team_a_action.empty? and team_b_action.empty?
    raise "Neither team had actions."
  elsif not team_a_action.empty? and not team_b_action.empty?
    raise "Both teams had actions: #{team_a_action}, #{team_b_action}"
  end

  action = team_a_action.empty? ? team_b_action : team_a_action

  state_number = nil
  events.keys.each_with_index do |event, idx|
    if events[event][:regex] =~ action
      state_number = idx
      break
    end
  end

  raise "No event found for #{action}" unless state_number

  if current_state
    transitions[current_state][state_number] += 1
  end
  current_state = state_number
end

transitions.each_with_index do |txns, idx|
  tx_map = {}
  txns.each {|k, num| tx_map[events.keys[k]] = num}
  puts "#{events.keys[idx]}: #{tx_map}"
end
puts '=' * 60
