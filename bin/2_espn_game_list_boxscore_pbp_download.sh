set -e

: INTERVAL=${INTERVAL:=30}

valid_boxscores=../data/valid_boxscores.tsv
invalid_boxscores=../data/invalid_boxscores.tsv
valid_playbyplays=../data/valid_playbyplays.tsv
invalid_playbyplays=../data/invalid_playbyplays.tsv

cat ../data/game_list_*.tsv | sort | uniq | while read game_id
do
  boxscore=../data/boxscore_$game_id.html
  playbyplay=../data/playbyplay_$game_id.html
  boxscore_parsed=../data/boxscore_$game_id.tsv
  playbyplay_parsed=../data/playbyplay_$game_id.tsv

  if [ ! -f $boxscore ] && [ "$1" != "--nodl" ]
  then
    curl -s -S "http://espn.go.com/mens-college-basketball/boxscore?gameId=$game_id" > $boxscore
    echo "Downloaded $boxscore"
    sleep $INTERVAL
  fi
  if [ ! -f $playbyplay ] && [ "$1" != "--nodl" ]
  then
    curl -s -S "http://espn.go.com/mens-college-basketball/playbyplay?gameId=$game_id" > $playbyplay
    echo "Downloaded $playbyplay"
    sleep $INTERVAL
  fi

  if [ ! -f $boxscore_parsed ]
  then
    regex="<tr[^>]*>\s*<td[^>]*>(?:<a href=\"[^\"]+/id/(?<player_id>\d+)[^\"]*\"[^>]*>)?"
    regex="$regex(?<player>[^<]*)(?:</a>)?"
    regex="$regex(?:, )?(?<position>[A-Z])?</td>"
    regex="$regex<td[^>]*>(?<minutes>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<fg>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<tpfg>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<ft>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<oreb>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<dreb>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<reb>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<ast>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<stl>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<blk>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<to>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<pf>[^<]*)</td>"
    regex="$regex<td[^>]*>(?<pts>[^<]*)</td></tr>"

    # find named instances of the given regex
    ./scrape.rb $boxscore "$regex" --headers > $boxscore_parsed
    event_count=$(wc -l $boxscore_parsed | grep -oP "^\d+")
    if [ $event_count -eq 0 ]
    then
      echo "*Retrieved no events from $boxscore_parsed"
      echo "$game_id" >> $invalid_boxscores
    else
      echo "Retrieved $event_count events from $boxscore_parsed"
      echo "$game_id" >> $valid_boxscores
    fi
  fi

  if [ ! -f $playbyplay_parsed ]
  then
    regex="<tr class=\"(?:even|odd)\"><td[^>]*>(?<time>[^<]*)</td>"
    regex="$regex<td[^>]*>(?:<b>|<B>)?(?:&nbsp;)?(?<team_a_action>[^<]*)(?:</b>|</B>)?</td>"
    regex="$regex<td[^>]*>(?<score>[^<]*)</td>"
    regex="$regex<td[^>]*>(?:<b>|<B>)?(?:&nbsp;)?(?<team_b_action>[^<]*)(?:</b>|</B>)?</td></tr>"

    # find named instances of the given regex
    ./scrape.rb $playbyplay "$regex" --headers > $playbyplay_parsed
    event_count=$(wc -l $playbyplay_parsed | grep -oP "^\d+")
    if [ $event_count -eq 0 ]
    then
      echo "*Retrieved no events from $playbyplay_parsed"
      echo "$game_id" >> $invalid_playbyplays
    else
      echo "Retrieved $event_count events from $playbyplay_parsed"
      echo "$game_id" >> $valid_playbyplays
    fi
  fi
done
