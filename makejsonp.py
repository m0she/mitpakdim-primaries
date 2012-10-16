import json, os, re

paths = dict(
    member = r'data\member.json',
    agenda = r'data\agenda.json',
    party = r'data\party.json',
    combined = r'data\combined_newbies.json',
    member_agendas = r'data\member-agendas\member-agendas.%d.json',
)
def load_json(path):
    try:
        return json.load(open(path))
    except:
        print 'Error with %s' % path
data = { k:load_json(v) for k,v in paths.items() if '%' not in v }

prefix = 'if (!window.mit) window.mit = {};\nwindow.mit.%s = '
def do_file(path, variable=None):
    path_split = os.path.splitext(path)
    if path_split[1] == '.json':
        path = path_split[0]
    in_path = path + '.json'
    out_path = path + '.jsonp'
    if not variable:
        variable = os.path.basename(path)
    data = json.load(open(in_path))
    out_file = open(out_path, 'w')
    out_file.write(prefix % (variable))
    json.dump(data, out_file, indent=4)


def process_member_agenda(member_agenda):
    res = {}
    for agenda in member_agenda['agendas']:
        res[agenda['id']] = agenda['score']
    return res

def combine_agendas(member_path, member_agendas_path, output_path):
    data = json.load(open(member_path))
    for member in data['objects']:
        #print 'Handling member: %d' % member['id']
        member_agenda = json.load(open(member_agendas_path % member['id']))
        member['name'] = 'XX' + member['name']
        member['agendas'] = process_member_agenda(member_agenda)
    json.dump(data, open(output_path, 'w'), indent=4)
