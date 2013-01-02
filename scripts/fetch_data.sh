#!/bin/bash

scripts_dir=$(cd $(dirname $0); pwd ); 
data_dir=${scripts_dir}/../data
datautils="python $scripts_dir/datautil.py"

cd $data_dir
if [ ! -e member_extra.json ]; then
    echo 'data directory should contain member.ids file'
fi
function get_with_retry {
    echo "getting $1 into $2"
    while ! curl $1 > $2 || grep 'Internal Server Error' $2 > /dev/null 2>&1 ; do
        echo "retrying $2"
    done
}

get_with_retry http://oknesset.org/api/v2/party/ party.json
get_with_retry "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name,links" member.json
get_with_retry "http://oknesset.org/api/v2/agenda/?extra_fields=num_followers,image,parties" agenda.json
$datautils jsonp party.json
$datautils jsonp party_extra.json
$datautils jsonp member.json
$datautils jsonp member_extra.json
$datautils jsonp agenda.json

grep '"id"' member.jsonp | awk '{print $2'} | cut -d, -f1 | sed -e 's/\"//g' > member.ids

cd member-agendas
for i in $(cat ../member.ids); do
    get_with_retry http://oknesset.org/api/v2/member-agendas/$i/ member-agendas.$i.json
done
cd ..

$datautils combine combined_members.json
$datautils jsonp combined_members.json
