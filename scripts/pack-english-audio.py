#!/usr/bin/env python3
"""Pack a downloaded WyabdcRealPeopleTTS archive for bounded Android playback.
Usage: python3 scripts/pack-english-audio.py archive.tar.bz2 output-directory
The source recordings are user data and are never bundled in the plugin ZIP.
"""
import pathlib, sys, tarfile
source, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
count = 0
skipped = []
with tarfile.open(source, 'r:bz2') as archive, (output/'english.pack.tmp').open('wb') as pack, (output/'english.tsv.tmp').open('w', encoding='utf-8') as index:
    for member in archive:
        if not member.isfile() or not member.name.lower().endswith('.wav'):
            continue
        name = pathlib.PurePosixPath(member.name).stem.lower()
        if any(c in name for c in '\t\r\n'):
            continue
        data = archive.extractfile(member).read()
        if not (data.startswith(b'RIFF') and data[8:12] == b'WAVE'):
            skipped.append(member.name)
            continue
        index.write(f'{name}\t{pack.tell()}\t{len(data)}\n')
        pack.write(data)
        count += 1
(output/'english.pack.tmp').replace(output/'english.pack')
(output/'english.tsv.tmp').replace(output/'english.tsv')
(output/'skipped-recordings.txt').write_text('\n'.join(skipped), encoding='utf-8')
print(f'Packed {count} English pronunciation recordings; skipped {len(skipped)} invalid source files')
