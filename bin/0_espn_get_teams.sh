set -e

root_dir=$(cd `dirname $0`/.. && pwd)

curl -s -S 'http://espn.go.com/mens-college-basketball/teams' > $root_dir/data/teams.html
echo "Downloaded $root_dir/data/teams.html"

$root_dir/bin/scrape.rb $root_dir/data/teams.html "<a\s+[^>]*href=['\"]?http://espn.go.com/mens-college-basketball/team/_/id/(?<team_id>\d+)/[^'\"\s]*['\"]?[^>]*>\s*([^<]*?)\s*</a>" > $root_dir/data/team_ids.tsv
team_count=$(wc -l $root_dir/data/team_ids.tsv | grep -oP "^\d+")
echo "Retrieved $team_count team IDs"
