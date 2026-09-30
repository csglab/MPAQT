#!/usr/bin/env python3
"""Update generated website links without changing preserved source READMEs."""
from pathlib import Path
import re
import sys

def normalize(content):
    content = content.replace('csglab/MPAQT_merged', 'csglab/MPAQT')
    content = content.replace('csglab/mpaqt2', 'csglab/MPAQT')
    content = content.replace('csglab.github.io/mpaqt2', 'csglab.github.io/MPAQT')
    # Historical READMEs are preserved, but their private-repository notices
    # must not appear in the public website generated from them.
    content = re.sub(r'<p>(?:The source repository is currently private\.|This method also requires access to the private source repository|This source-installation command requires access to the private)[\s\S]*?</p>',
                     '<p>The source repository is public. GitHub credentials are optional for installation and can help avoid API rate limits.</p>', content)
    content = re.sub(r'<p>Repository members can report issues at[\s\S]*?</p>',
                     '<p>Report issues at <a href="https://github.com/csglab/MPAQT/issues">github.com/csglab/MPAQT/issues</a>.</p>', content)
    return content

if __name__ == '__main__':
    root = Path(sys.argv[1])
    changed = 0
    for path in root.rglob('*'):
        if not path.is_file() or '.git' in path.parts or path.suffix not in {'.html','.xml','.json','.yml','.yaml','.webmanifest'}:
            continue
        old = path.read_text()
        new = normalize(old)
        if old != new:
            path.write_text(new)
            changed += 1
    print(f'Updated {changed} generated website files.')
