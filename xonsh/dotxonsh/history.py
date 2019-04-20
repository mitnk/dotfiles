import builtins
import itertools
import json
import requests
import sys
import time
import uuid
from xonsh.history.sqlite import SqliteHistory


class HybriDBHistory(SqliteHistory):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.sessionid = self._build_session_id()
        self._couch_last_hist_inp = None

    def _build_session_id(self):
        ts = int(time.time() * 1000)
        return '{}-{}'.format(ts, str(uuid.uuid4())[:18])

    def append(self, cmd):
        super().append(cmd)
        self._save_to_couchdb(cmd)

    def _save_to_couchdb(self, cmd):
        envs = builtins.__xonsh_env__
        opts = envs.get('HISTCONTROL')
        inp = cmd['inp'].rstrip()
        if 'ignoredups' in opts and inp == self._couch_last_hist_inp:
            # Skipping dup cmd
            return
        if 'ignoreerr' in opts and cmd['rtn'] != 0:
            # Skipping failed cmd
            return
        self._couch_last_hist_inp = inp
        data = cmd.copy()
        data['inp'] = data['inp'].rstrip()
        if 'out' in data:
            data.pop('out')
        data['_id'] = self._build_doc_id()
        try:
            self._request_db_data('/xonsh-history', data=data)
        except Exception as e:
            msg = 'failed to save history: {}: {}'.format(e.__class__.__name__, e)
            print(msg, file=sys.stderr)

    def _build_doc_id(self):
        ts = int(time.time() * 1000)
        return '{}-{}-{}'.format(self.sessionid, ts, str(uuid.uuid4())[:18])

    def _request_db_data(self, path, data=None):
        url = 'http://127.0.0.1:5984' + path
        headers = {'Content-Type': 'application/json'}
        if data is not None:
            resp = requests.post(url, json.dumps(data), headers=headers)
        else:
            headers = {'Content-Type': 'text/plain'}
            resp = requests.get(url, headers=headers)
        return resp

    def _get_couchdb_doc_count(self):
        resp = self._request_db_data('/xonsh-history')
        data = json.loads(resp.text)
        return data.get('doc_count', '0')

    def info(self):
        data = super().info()
        data['backend'] = 'hybridb'
        data['all items'] = 'sqlite:{} / couch:{}'.format(
            data['all items'], self._get_couchdb_doc_count())
        return data

    def _get_db_items(self, sessionid=None):
        path = '/xonsh-history/_all_docs?include_docs=true'
        if sessionid is not None:
            path += '&start_key="{0}"&end_key="{0}-z"'.format(sessionid)
        try:
            r = self._request_db_data(path)
        except Exception as e:
            msg = 'error when query db: {}: {}'.format(e.__class__.__name__, e)
            print(msg, file=sys.stderr)
            return
        data = json.loads(r.text)
        for item in data['rows']:
            cmd = item['doc'].copy()
            try:
                cmd['ts'] = cmd['ts'][0]
            except TypeError:
                cmd['ts'] = 0
            yield cmd

    def all_items(self):
        """Display all history items."""
        yield from super().all_items()
        # items_sqlite = list(super().all_items())
        # items_couch = list(self._get_db_items())
        # yield from itertools.chain(items_sqlite, items_couch)
