#!/usr/bin/env python3
"""Render clear Spanish offline clips using Piper and lossless FLAC.

Usage: python pack-spanish-neural.py old-spanish-audio model.onnx output-dir
Requires piper-tts, numpy, onnxruntime and soundfile. Synthesizes locally.
A matching partial pack resumes automatically; changing model or pace is refused.
"""
import hashlib, io, json, multiprocessing as mp, os, pathlib, shutil, sys, time
VOICE = None
CONFIG = None

def init_worker(model, pace, threads):
    global VOICE, CONFIG
    import onnxruntime as ort
    import piper.voice
    from piper import PiperVoice, SynthesisConfig
    from piper.config import PiperConfig
    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    options.inter_op_num_threads = 1
    options.log_severity_level = 3
    session = ort.InferenceSession(str(model), sess_options=options, providers=['CPUExecutionProvider'])
    session.disable_telemetry_events() if hasattr(session, 'disable_telemetry_events') else None
    VOICE = PiperVoice(config=PiperConfig.from_dict(json.loads(pathlib.Path(str(model)+'.json').read_text())),
                       session=session, espeak_data_dir=pathlib.Path(piper.voice.__file__).parent/'espeak-ng-data')
    CONFIG = SynthesisConfig(length_scale=pace, noise_scale=.55, noise_w_scale=.6, normalize_audio=True)

def render_batch(terms):
    import numpy as np
    import soundfile as sf
    result=[]
    for term in terms:
        chunks=list(VOICE.synthesize(term if term.endswith(('.', '!', '?')) else term+'.', syn_config=CONFIG))
        if not chunks: raise ValueError(f'No speech for {term!r}')
        rate=chunks[0].sample_rate
        pieces=[]
        for i,chunk in enumerate(chunks):
            if i: pieces.append(np.zeros(int(rate*.15),dtype=np.int16))
            pieces.append(chunk.audio_int16_array)
        samples=np.concatenate(pieces)
        if samples.size<rate*.07 or np.max(np.abs(samples.astype(np.int32)))<500:
            raise ValueError(f'Empty or silent speech for {term!r}')
        stream=io.BytesIO()
        sf.write(stream,samples,rate,format='FLAC',subtype='PCM_16')
        result.append((term,stream.getvalue()))
    return result

def main():
    source,model,output=map(pathlib.Path,sys.argv[1:4])
    pace=float(os.environ.get('SPANISH_PACE','1.12'))
    workers=int(os.environ.get('SPANISH_WORKERS','4'))
    threads=int(os.environ.get('SPANISH_THREADS','4'))
    terms=[line.split('\t',1)[0] for line in (source/'spanish.tsv').read_text().splitlines()]
    output.mkdir(parents=True,exist_ok=True)
    manifest={'model_sha256':hashlib.sha256(model.read_bytes()).hexdigest(),
              'terms_sha256':hashlib.sha256('\n'.join(terms).encode()).hexdigest(),
              'pace':pace,'sample_rate':22050,'encoding':'FLAC PCM_16'}
    stamp=output/'generation.json'
    if stamp.exists(): assert json.loads(stamp.read_text())==manifest,'Output belongs to a different voice or pace'
    else: stamp.write_text(json.dumps(manifest,indent=2))
    pack_path,index_path=output/'spanish.pack.partial',output/'spanish.tsv.partial'
    completed,end=0,0
    if index_path.exists():
        for line in index_path.read_text().splitlines():
            word,offset,length=line.split('\t')
            assert word==terms[completed]
            end=int(offset)+int(length);completed+=1
    if not pack_path.exists(): assert completed==0
    batches=[terms[i:i+16] for i in range(completed,len(terms),16)]
    start=time.monotonic()
    with pack_path.open('r+b' if pack_path.exists() else 'w+b') as pack, index_path.open('a',encoding='utf8') as index:
        assert pack.seek(0,2)>=end
        pack.truncate(end);pack.seek(end)
        with mp.get_context('spawn').Pool(workers,initializer=init_worker,initargs=(str(model),pace,threads)) as pool:
            last=0
            for batch in pool.imap(render_batch,batches,chunksize=1):
                for word,audio in batch:
                    index.write(f'{word}\t{pack.tell()}\t{len(audio)}\n');pack.write(audio);completed+=1
                now=time.monotonic()
                if now-last>=20:
                    pack.flush();index.flush();last=now
                    print(f'{completed}/{len(terms)} clear Spanish clips; {now-start:.0f}s; {pack.tell()/1024**2:.1f} MiB',flush=True)
    pack_path.replace(output/'spanish.pack');index_path.replace(output/'spanish.tsv')
    shutil.copy2(source/'spanish-translations.tsv',output/'spanish-translations.tsv')
    (output/'SOURCE.txt').write_text('Locally synthesized with Piper es_MX-claude-high (Mexican Spanish), 22,050 Hz, 16-bit, lossless FLAC. Pace 1.12. Voice dataset license Apache-2.0; model card https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_MX/claude/high/MODEL_CARD. Piper engine https://github.com/OHF-Voice/piper1-gpl (GPL-3.0). Translation text: WikDict English–Spanish, CC BY-SA 4.0.\n')
    print(f'Completed {completed} neural Spanish clips',flush=True)
if __name__=='__main__':main()
