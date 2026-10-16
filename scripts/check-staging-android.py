#!/usr/bin/env python3
"""Fail closed before building an isolated preview APK. No credentials accepted."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.parse import urlsplit


def validate(ref, api, production_urls):
    if ref not in ('refs/heads/develop', 'refs/heads/staging'):
        raise ValueError('Only develop/staging branch refs may build this APK')
    if any(ord(char) <= 32 for char in api):
        raise ValueError('Whitespace/control characters are not allowed')
    parsed = urlsplit(api)
    hostname = (parsed.hostname or '').rstrip('.')
    if not re.fullmatch(r'[a-z0-9.-]+', hostname):
        raise ValueError('API hostname must use a plain DNS/IP spelling')
    production_hosts = {'zestfully-usable-pledge.ngrok-free.dev', 'api.brin.fajrianhost.my.id'}
    production = [urlsplit(value) for value in production_urls if value]
    production_hosts.update((value.hostname or '').rstrip('.') for value in production)
    branch_path = '/' + ref.rsplit('/', 1)[1] + '/api'
    allowed_paths = {branch_path, branch_path + '/'}
    if hostname not in production_hosts:
        allowed_paths.update({'/api', '/api/'})
    same_production_endpoint = any(
        (parsed.scheme, hostname, parsed.port or 443, parsed.path.rstrip('/'))
        == (value.scheme, (value.hostname or '').rstrip('.'), value.port or 443, value.path.rstrip('/'))
        for value in production)
    if (parsed.scheme != 'https' or not hostname or hostname in {'localhost', '127.0.0.1', '::1'}
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in allowed_paths or parsed.port not in (None, 443) or same_production_endpoint):
        raise ValueError('Preview API must be HTTPS with a branch-safe API path and no credentials/query/fragment')
    return api.rstrip('/')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', type=Path)
    parser.add_argument('--metadata', type=Path)
    args = parser.parse_args()
    try:
        api = validate(os.environ.get('GITHUB_REF', ''), os.environ.get('API_BASE_URL', ''),
                       [os.environ.get(key, '') for key in ('PRODUCTION_API_URL', 'LEGACY_PRODUCTION_API_URL', 'NGROK_PRODUCTION_API_URL')])
        if args.metadata:
            if args.apk is None or not args.apk.is_file():
                raise ValueError('APK required for metadata')
            sha = os.environ.get('GITHUB_SHA', '')
            if len(sha) != 40 or any(c not in '0123456789abcdef' for c in sha):
                raise ValueError('Source SHA unavailable')
            metadata = {'source_sha': sha, 'source_ref': os.environ['GITHUB_REF'], 'api_base_url': api,
                        'application_id': 'id.go.brin.neutronct.staging', 'visible_name': 'deepCT-AI Staging',
                        'flutter_version': '3.44.9', 'build_mode': 'debug', 'signing': 'ephemeral CI debug key',
                        'apk_sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
                        'physical_android_tested': False, 'production_activation': False}
            args.metadata.write_text(json.dumps(metadata, indent=2) + '\n')
        print('Staging Android preflight passed')
        return 0
    except (ValueError, OSError):
        print('Staging Android preflight failed: check branch and preview API configuration')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
