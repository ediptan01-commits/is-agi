"""Check the app's embedded profile queries against the real PostgREST API."""
import json
from pathlib import Path
import re
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError

root = Path(__file__).resolve().parents[1]
config = json.loads((root / 'config/client.json').read_text(encoding='utf-8-sig'))
source = '\n'.join(path.read_text(encoding='utf-8') for path in (root / 'lib').glob('*.dart'))
queries = re.findall(r"\.from\('([^']+)'\)\s*\.select\('([^']+)'\)", source)
checked = 0
for table, select in queries:
    if 'profiles' not in select:
        continue
    url = config['SUPABASE_URL'] + '/rest/v1/' + table + '?' + urlencode({'select': select, 'limit': '0'})
    request = Request(url, headers={'apikey': config['SUPABASE_ANON_KEY']})
    # No user session: validate relationship resolution without retrieving user data.
    try:
        with urlopen(request, timeout=30) as response:
            assert response.status == 200, f'{table}: HTTP {response.status}'
            assert json.load(response) == [], f'{table}: expected zero rows'
    except HTTPError as error:
        payload = json.load(error)
        # Stories deliberately deny anonymous API access even to zero-row queries.
        assert table == 'stories' and error.code in (401, 403) and payload.get('code') == '42501', payload
    print(f'{table}: profile relationship resolved')
    checked += 1
assert checked > 0, 'No embedded profile queries found'
