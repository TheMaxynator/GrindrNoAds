#!/usr/bin/env python3
"""Offline configuration/packaging tests. Does not execute iOS hooks."""
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
layout = ROOT / 'layout' / 'Library' / 'Application Support' / 'GrindrNoAds'

errors = []
def check(truth, message):
    print(('PASS' if truth else 'FAIL') + '  ' + message)
    if not truth:
        errors.append(message)

filt = plistlib.loads((ROOT / 'GrindrNoAds.plist').read_bytes())
settings = plistlib.loads((layout / 'settings.plist').read_bytes())
domains = plistlib.loads((layout / 'blocked-domains.plist').read_bytes())
check(filt == {'Filter': {'Bundles': ['com.grindrguy.grindrx']}}, 'Only Grindr injection; no SpringBoard')
check(settings.get('NetworkBlockingEnabled') is True, 'Network hook enabled by default')
check(settings.get('AggressiveManagerResetEnabled') is False, 'Dangerous manager reset opt-in only')
check(len(domains) == 10 and len(set(domains)) == 10, 'Expected ten distinct domain rules')
check(all(isinstance(d, str) and '.' in d for d in domains), 'Hostname rules are plausibly valid')

# Match the intended Objective-C behavior: exact host or dot-boundary suffix.
def would_block(host):
    host = host.lower().rstrip('.')
    return any(host == d or host.endswith('.' + d) for d in domains)

for host, expected in {
    'applovin.com': True, 'ads.applovin.com': True,
    'notapplovin.com': False, 'safe.example': False,
    'ads.doubleclick.net': True, 'someonelink.me': False,
    'OnElInK.Me': True, 'x.mtgglobals.com': True,
}.items():
    check(would_block(host) == expected, f'Boundary test: {host}')

source = '\n'.join(path.read_text() for path in [ROOT/'Tweak.xm', *sorted((ROOT/'Sources').glob('*.m'))])
check('MSHookMessageEx' in source, 'Real Substrate hooking implementation present')
for selector in ('dataTaskWithRequest:completionHandler:', 'didMoveToWindow', 'layoutSubviews', 'viewDidLoad'):
    check(selector in source, f'Original hook target reconstructed: {selector}')
for forbidden in ('MGCopyAnswer', 'UniqueDeviceID', 'api.yourepo.com', 'com.gdx.dd', 'libSandy_applyProfile', 'exit(0)'):
    check(forbidden not in source, f'No legacy license/UDID runtime: {forbidden}')
check('com.apple.springboard' not in (ROOT/'GrindrNoAds.plist').read_text(), 'Filter contains no SpringBoard')
check('THEOS_PACKAGE_SCHEME = rootless' in (ROOT/'Makefile').read_text(), 'Theos rootless package scheme')
check('Conflicts: com.0xkuj.grindruntuckednoads' in (ROOT/'control').read_text(), 'Package conflicts with original tweak')
check(not list(ROOT.rglob('*.dylib')), 'No repackaged third-party executable')
print(f'\n{len(errors)} failing check(s). NOTE: these are STATIC tests, not an iOS compile/runtime test.')
sys.exit(1 if errors else 0)
