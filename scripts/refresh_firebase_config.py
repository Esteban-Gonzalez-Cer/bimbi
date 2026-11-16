#!/usr/bin/env python3
"""Read a CLI apps:sdkconfig --json file without printing any configuration values."""
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
config = json.loads(payload['result']['fileContents'])
client = next(c for c in config['client'] if c['client_info']['android_client_info']['package_name'] == 'com.bimbi.app')
path = Path('config/dev.json')
settings = json.loads(path.read_text() if path.exists() else Path('config/dev.example.json').read_text())
project = config['project_info']
settings.update(FIREBASE_PROJECT_ID=project['project_id'], FIREBASE_APP_ID=client['client_info']['mobilesdk_app_id'], FIREBASE_API_KEY=client['api_key'][0]['current_key'], FIREBASE_SENDER_ID=project['project_number'])
for field, source in [('FIREBASE_DATABASE_URL','firebase_url'),('FIREBASE_STORAGE_BUCKET','storage_bucket')]:
    if project.get(source): settings[field] = project[source]
settings['GOOGLE_SERVER_CLIENT_ID'] = next((c['client_id'] for c in client.get('oauth_client',[]) if c['client_type'] == 3), '')
path.write_text(json.dumps(settings, indent=2) + '\n')
Path('android/app/google-services.json').write_text(json.dumps(config, indent=2) + '\n')
print('Local Firebase configuration refreshed; no keys printed.')
