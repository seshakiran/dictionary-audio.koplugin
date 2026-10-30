#!/usr/bin/env python3
"""Generate offline Latin American Spanish clips for WikDict translations.
Requires the official eSpeak NG shared library (brew install espeak-ng).
Usage: python3 scripts/pack-spanish-audio.py stardict.idx stardict.dict output-dir
All dictionary meanings are merged; each distinct translation is stored once.
"""
import ctypes as c, ctypes.util, html, io, pathlib, re, struct, sys, wave
idx_path, dict_path, output = map(pathlib.Path, sys.argv[1:4])
output.mkdir(parents=True, exist_ok=True)
idx, definitions = idx_path.read_bytes(), dict_path.read_bytes()
translations, terms = {}, set()
position = 0
while position < len(idx):
    end = idx.index(0, position)
    word = idx[position:end].decode('utf8').lower()
    offset, length = struct.unpack('>II', idx[end+1:end+9])
    position = end+9
    found = translations.setdefault(word, [])
    for term in re.findall(r'<div>([^<>]+)</div>', definitions[offset:offset+length].decode('utf8')):
        term = html.unescape(term)
        term = re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]+)\]\]', r'\1', term)
        term = ' '.join(term.split())
        if not term or len(term)>180 or not any(char.isalpha() for char in term):
            continue
        if term not in found: found.append(term)
        terms.add(term)
lib = c.CDLL(ctypes.util.find_library('espeak-ng'))
lib.espeak_Initialize.argtypes = [c.c_int,c.c_int,c.c_char_p,c.c_int]
rate = lib.espeak_Initialize(2,0,None,0)
assert rate>0 and rate%2==0
callback_type = c.CFUNCTYPE(c.c_int,c.POINTER(c.c_short),c.c_int,c.c_void_p)
chunks = []
@callback_type
def callback(samples,count,events):
    if samples and count>0: chunks.append(c.string_at(samples,count*2))
    return 0
lib.espeak_SetSynthCallback(callback)
lib.espeak_SetVoiceByName.argtypes = [c.c_char_p]
assert lib.espeak_SetVoiceByName(b'es-419')==0
lib.espeak_Synth.argtypes = [c.c_void_p,c.c_size_t,c.c_uint,c.c_int,c.c_uint,c.c_uint,c.c_void_p,c.c_void_p]
unsigned = bytes((i+128)%256 for i in range(256))
with (output/'spanish.pack.tmp').open('wb') as pack, (output/'spanish.tsv.tmp').open('w',encoding='utf8') as index:
    for number,term in enumerate(sorted(terms),1):
        chunks.clear()
        data=term.encode('utf8')+b'\0'
        assert lib.espeak_Synth(data,len(data),0,0,0,1,None,None)==0
        # Native-endian signed 16-bit to unsigned 8-bit PCM at half the rate.
        # This reduces storage and MTP transfer size; synthesis remains offline.
        raw=b''.join(chunks)
        pcm=raw[1 if sys.byteorder=='little' else 0::4].translate(unsigned)
        stream=io.BytesIO()
        with wave.open(stream,'wb') as wav:
            wav.setnchannels(1);wav.setsampwidth(1);wav.setframerate(rate//2);wav.writeframes(pcm)
        recording=stream.getvalue()
        index.write(f'{term}\t{pack.tell()}\t{len(recording)}\n')
        pack.write(recording)
        if number%10000==0: print(f'{number}/{len(terms)} Spanish pronunciations',flush=True)
for name in ['spanish.pack','spanish.tsv']:
    (output/(name+'.tmp')).replace(output/name)
with (output/'spanish-translations.tsv').open('w',encoding='utf8') as out:
    for word, choices in sorted(translations.items()):
        if choices and '\t' not in word and '\n' not in word:
            out.write('\t'.join([word]+choices)+'\n')
(output/'SOURCE.txt').write_text('Synthesized locally using eSpeak NG 1.52.0, voice es-419 (Latin America). These are synthetic pronunciations, not human recordings. Translation text comes from WikDict English–Spanish (CC BY-SA 4.0), https://www.wikdict.com/page/download. Engine source: https://github.com/espeak-ng/espeak-ng (GPL-3.0-or-later).\n')
print(f'Generated {len(terms)} Spanish pronunciations for {len(translations)} English headwords',flush=True)
