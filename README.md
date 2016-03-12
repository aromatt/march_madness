# March Madness Toolkit

This is a collection of tools used to help with the annual March Madness
bracket prediction tradition. This is a rewrite of the ancient C# tools for
scraping and data aggregation.

## Tools

The scope of this project includes tools for:

 - scraping of files (downloaded web pages) for data

## Dependencies

 - Ruby 1.9

## Usage

### Scraping for tokens in a file

Given a file that contains data that can be found with regular expressions,
use the `./bin/scrape.rb` tool finding the tokens and output them in tab-
delimited format to stdout. Note that this could be done with a combination
of `grep` and `sed` to the same effect.

`./bin/scrape.rb source_file regex [--headers]`

Example:

`./bin/scrape.rb data/teams.html "<a\s+[^>]*href=['\"]?[^'\"\s]*/team/_/id/(?<team_id>\d+)/[^'\"\s]*['\"]?[^>]*>\s*(?<team_name>[^<]*?)\s*</a>"`

... creates a tab-delimited file with two columns: `team_id` and `team_name`.
Add the argument `--headers` to the end to add a row at the top of the file
for `team_id` and `team_name`.

## Example workflow

All steps in this example workflow assume you are working from `./data`.

### Download a list of teams from your favorite source

curl `http://example.com/teams > teams.html`

### Scrape team IDs off of the downloaded page

`../bin/scrape.rb teams.html "<a\s+[^>]*href=['\"]?[^'\"\s]*/team/_/id/(?<team_id>\d+)/[^'\"\s]*['\"]?[^>]*>\s*([^<]*?)\s*</a>" > team_ids.tsv`

### Download the schedule from each of the teams

`cat team_ids.tsv | while read team_id; do curl "http://example.com/team/schedule/id/$team_id" > schedules_$team_id.html; sleep 10; done`

### Get the game IDs from each of the teams' schedules

`ls schedules_*.html | while read line; do id=$(echo $line | grep -oP '\d+'); ../bin/scrape.rb $line "<a\s+[^>]*href=['\"]/ncb/recap\?gameId=(?<game_id>\d+)" > game_list_$id.tsv; done`

### Download all of the boxscores and play-by-play pages

`cat game_list_*.tsv | sort | uniq | while read line; do curl "http://example.com/boxscore?gameId=$line" > boxscore_$line.html; sleep 10; curl "http://example.com/playbyplay?gameId=$line" > playbyplay_$line.html; sleep 10; done`

Note: to skip files that have already been downloaded, use the following:

`cat game_list_*.tsv | sort | uniq | while read line; do if [ ! -f boxscore_$line.html ]; then curl "http://example.com/boxscore?gameId=$line" > boxscore_$line.html; sleep 10; fi; if [ ! -f playbyplay_$line.html ]; then curl "http://example.com/playbyplay?gameId=$line" > playbyplay_$line.html; sleep 10; fi; done`
