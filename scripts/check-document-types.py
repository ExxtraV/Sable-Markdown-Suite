#!/usr/bin/env python3
"""Checks Info.plist's document types: Sable offers itself for Markdown and plain text, but never claims to be the default."""
import plistlib, sys

with open('Info.plist', 'rb') as handle:
    plist = plistlib.load(handle)

failures = []
def need(ok, message):
    if not ok: failures.append(message)

types = plist.get('CFBundleDocumentTypes', [])
by_content = {}
for entry in types:
    for uti in entry.get('LSItemContentTypes', []):
        by_content.setdefault(uti, []).append(entry)

markdown, text = by_content.get('net.daringfireball.markdown', []), by_content.get('public.plain-text', [])
need(len(markdown) == 1, 'Exactly one document type should declare Markdown.')
need(len(text) == 1, 'Exactly one document type should declare plain text.')
# Markdown and plain text are separate entries, so one can be handled differently from the other.
need(not (markdown and text and markdown[0] is text[0]), 'Markdown and plain text must be separate document types.')
for entry in types:
    need(entry.get('LSHandlerRank') == 'Alternate', f"{entry.get('CFBundleTypeName')}: LSHandlerRank must stay Alternate; making Sable the default is the user's choice in Settings.")
    need(entry.get('CFBundleTypeRole') == 'Editor', f"{entry.get('CFBundleTypeName')}: role should be Editor.")

declared = {}
for entry in plist.get('UTImportedTypeDeclarations', []):
    declared[entry.get('UTTypeIdentifier')] = entry
markdown_type = declared.get('net.daringfireball.markdown')
need(markdown_type is not None, 'net.daringfireball.markdown must be declared.')
if markdown_type:
    extensions = markdown_type.get('UTTypeTagSpecification', {}).get('public.filename-extension', [])
    for extension in ['md', 'markdown', 'mdown', 'mkd', 'mkdn', 'mdwn']:
        need(extension in extensions, f'The Markdown type should list the .{extension} extension.')
    need('public.plain-text' in markdown_type.get('UTTypeConformsTo', []), 'Markdown should conform to public.plain-text.')

if failures:
    print('\n'.join(failures))
    sys.exit(1)
print('Passed: document type checks')
