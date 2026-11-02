#!/usr/bin/env python3
"""Fetch immutable native combat sources and the released Off regression oracle."""
import argparse, concurrent.futures, hashlib, json, subprocess, urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--sources',type=Path,default=ROOT/'dist/adaptive-sources');args=p.parse_args()
def fetch(row):
 target=args.sources/(row['repository'].split('/')[-1]+'-world')
 if not (target/'.git').exists():
  target.mkdir(parents=True,exist_ok=True)
  subprocess.run(['git','init','-q',str(target)],check=True)
  subprocess.run(['git','-C',str(target),'remote','add','origin','https://github.com/'+row['repository']+'.git'],check=True)
 subprocess.run(['git','-C',str(target),'fetch','-q','--depth','1','origin',row['revision']],check=True)
 subprocess.run(['git','-C',str(target),'checkout','-q','--detach',row['revision']],check=True)
 for rel,digest in row['files'].items():
  assert hashlib.sha256((target/rel).read_bytes()).hexdigest()==digest,rel
 return row['repository']
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for repo in pool.map(fetch,json.loads((ROOT/'tools/adaptive_native_references.json').read_text())):print('Verified',repo)
for version,revision,digest in [
 ('1.8.0','89a198e8af26227ec5cb3243d47ce3a844927490','43214fcac18527452f04b46dace2fb1abe72600409d7da2afe467e1e1bdc07e2'),
 ('1.9.0','b9658d57665cf09aa18ef99ca66f6992409ac8d1','288a5b594a93895058dc5806573bea2ab8946c632d5794572e890b71476dde8c'),
]:
 baseline=ROOT/('dist/baseline/randomizer-'+version+'.lua')
 url='https://raw.githubusercontent.com/weskestis/UniversalRandomizer/'+revision+'/mod/randomizer.lua'
 data=baseline.read_bytes() if baseline.exists() else urllib.request.urlopen(url,timeout=90).read()
 assert hashlib.sha256(data).hexdigest()==digest
 baseline.parent.mkdir(parents=True,exist_ok=True);baseline.write_bytes(data)
 print('Verified published '+version+' regression source')
