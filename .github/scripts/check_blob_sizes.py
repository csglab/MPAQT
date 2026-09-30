#!/usr/bin/env python3
"""Reject large Git blobs anywhere in reachable branch/tag history."""
import subprocess
objects = subprocess.check_output(['git', 'rev-list', '--objects', '--all'])
rows = subprocess.check_output(['git', 'cat-file', '--batch-check=%(objecttype) %(objectsize) %(rest)'], input=objects).decode().splitlines()
bad = [r for r in rows if r.startswith('blob ') and int(r.split(' ', 2)[1]) > 5*1024*1024]
if bad:
    raise SystemExit('Files exceed the 5 MiB limit:\n' + '\n'.join(bad))
print('PASS: all reachable Git blobs are at most 5 MiB.')
