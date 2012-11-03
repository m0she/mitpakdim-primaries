if [ ! -e member.ids ]; then
    echo 'Should be run from data directory, which should contain member.ids file'
fi
function get_with_retry {
    echo "getting $1 into $2"
    while ! curl $1 > $2 || grep 'Internal Server Error' $2 > /dev/null 2>&1 ; do
        echo "retrying $2"
    done
}

get_with_retry http://oknesset.org/api/v2/party/ party.json
get_with_retry "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name" member.json
get_with_retry "http://oknesset.org/api/v2/agenda/?extra_fields=num_followers" agenda.json
python ../datautil.py jsonp party.json
python ../datautil.py jsonp member.json
python ../datautil.py jsonp agenda.json

grep '"id"' member.jsonp | awk '{print $2'} | cut -d, -f1 > member.ids

cd member-agendas
for i in $(cat ../member.ids); do
    get_with_retry http://oknesset.org/api/v2/member-agendas/$i/ member-agendas.$i.json
done
cd ..

python ../datautil.py combine combined_members.json
python ../datautil.py jsonp combined_members.json
