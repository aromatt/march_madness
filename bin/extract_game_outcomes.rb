#!/usr/bin/env ruby
require 'json'

ARGV.each do |file|
  teams = {}
  File.open(file, 'r') do |f|
    lines = f.readlines
    # TODO Need to determine both teams first.
    # Skip file unless we have two teams (sometimes they are missing)
    lines.each do |line|
      team = line.split("\t")[2].to_i
      next unless team > 0
      teams[team] = 1
      break if teams.keys.count == 2
    end
    break if teams.keys.count < 2
    winner = lines.last.split("\t")[2].to_i
    scores = lines.last.split("\t")[1].gsub(/-/, '').split(" ").map(&:to_i)
    diff = scores.max - scores.min
    loser = teams.keys.select { |x| x != winner }.first
    obj = {
      game: File.basename(file).split(/_|\./)[1].to_i,
      winner: winner,
      loser: loser,
      score_diff: diff
    }
    puts obj.to_json
  end
end
