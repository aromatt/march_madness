set -e

: INTERVAL=${INTERVAL:=30}

cat ../data/team_ids.tsv | while read team_id
do
  schedule=../data/schedules_$team_id.html
  game_list=../data/game_list_$team_id.tsv
  game_status=../data/game_status_$team_id.tsv

  if [ "--nodl" != "$1" ]
  then
    echo "Download the schedules for team ID $team_id"
    curl -s -S "http://espn.go.com/mens-college-basketball/team/schedule/_/id/$team_id" > $schedule
    sleep $INTERVAL
  fi

  echo "Scrape the game IDs from team ID $team_id's schedule"
  ./scrape.rb $schedule "<a\s+[^>]*href=['\"]/ncb/(?:[a-z]*)\?gameId=(?<game_id>\d+)" > $game_list
  #./scrape.rb ../data/schedules_2463.html "(?<status>[^>]*)</span></li><li[^>]*><a\s+[^>]*href=['\"]/ncb/(?:recap|boxscore)\?gameId=(?<game_id>\d+)\">(?<score>[^<]*)</a>" > $game_status

  game_count=$(wc -l $game_list | grep -oP "^\d+")
  echo "Retrieved $game_count game IDs from $team_id ($game_list)"

done

