import json, os, re
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
