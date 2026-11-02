#!/usr/bin/env python3
"""Verify immutable Gen 2 map/script references and their native warp fixture."""
import concurrent.futures
import hashlib
import json
import re
from pathlib import Path
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
SPEC=json.loads((ROOT/'tools/gen2_world_references.json').read_text())
CACHE=ROOT/'dist/gen2-world-sources'
SELECTED={'VIOLET_GYM','AZALEA_GYM','GOLDENROD_GYM','ECRUTEAK_GYM','OLIVINE_GYM','CIANWOOD_GYM','MAHOGANY_GYM','BLACKTHORN_GYM_1F','PEWTER_GYM','CERULEAN_GYM','VERMILION_GYM','CELADON_GYM','FUCHSIA_GYM','SAFFRON_GYM','SEAFOAM_GYM','VIRIDIAN_GYM','SPROUT_TOWER_1F','UNION_CAVE_1F','SLOWPOKE_WELL_B1F','BURNED_TOWER_1F','OLIVINE_LIGHTHOUSE_1F','ICE_PATH_1F','DRAGONS_DEN_1F','TOHJO_FALLS','ROCK_TUNNEL_1F','DIGLETTS_CAVE','MOUNT_MOON','SILVER_CAVE_ROOM_1'}

def fetch(row):
    target=CACHE/row['repo'].replace('/','-')/row['path']
    url=f"https://raw.githubusercontent.com/{row['repo']}/{row['commit']}/{row['path']}"
    data=target.read_bytes() if target.exists() else urllib.request.urlopen(url,timeout=60).read()
    assert hashlib.sha256(data).hexdigest()==row['sha256'],url
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    if row.get('baseline'):
        baseline=ROOT/'dist/baseline/randomizer-1.7.0.lua'
        baseline.parent.mkdir(parents=True,exist_ok=True);baseline.write_bytes(data)
    return target

def lua(value):
    if isinstance(value,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in value.items())+'}'
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    return json.dumps(value)

def fixture():
    editions={}
    for version,repo in [('crystal','pokecrystal'),('gold','pokegold')]:
        src=CACHE/('pret-'+repo)
        # Independent source check for the per-edition badge adapter. Crystal
        # inserts MOBILE_SYSTEM before the badges; Gold/Silver do not.
        flags=re.findall(r'^\s*const\s+(ENGINE_\w+)',(src/'constants/engine_flags.asm').read_text(),re.M)
        first=27 if version=='crystal' else 26
        badges=['ZEPHYR','HIVE','PLAIN','FOG','MINERAL','STORM','GLACIER','RISING','BOULDER','CASCADE','THUNDER','RAINBOW','SOUL','MARSH','VOLCANO','EARTH']
        assert flags[first:first+16]==['ENGINE_'+b+'BADGE' for b in badges], 'Native badge constants changed'
        ids=dict(re.findall(r'^\s*map_attributes\s+(\w+),\s*(\w+)',(src/'data/maps/attributes.asm').read_text(),re.M))
        envs=dict(re.findall(r'^\s*map\s+(\w+),\s*\w+,\s*(\w+)',(src/'data/maps/maps.asm').read_text(),re.M))
        maps={}
        for label,id in ids.items():
            path=src/'maps'/(label+'.asm')
            if not path.exists():continue
            warps=[dict(x=int(x),y=int(y),destMap=d,destWarp=int(n)) for x,y,d,n in re.findall(r'^\s*warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(-?\d+)',path.read_text(),re.M)]
            maps[id]=dict(environment=envs[label],warps=warps,label=label)
        keep=set(SELECTED)
        for id,m in maps.items():
            if m['environment'] in ('TOWN','ROUTE') and any(w['destMap'] in SELECTED for w in m['warps']):keep.add(id)
        editions[version]={k:v for k,v in sorted(maps.items()) if k in keep}
    expected='-- Native warp coordinates extracted from hash-pinned pret Gold/Crystal sources.\nreturn '+lua(editions)+'\n'
    assert expected==(ROOT/'tests/support/gen2_portals.lua').read_text(),'Native portal fixture differs from pinned sources'

if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        result=list(pool.map(fetch,SPEC['files']))
    fixture()
    print(f'Verified {len(result)} pinned sources and both native Gen 2 warp fixtures')
