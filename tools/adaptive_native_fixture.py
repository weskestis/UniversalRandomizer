#!/usr/bin/env python3
"""Generate small battle registries from pinned, public pret source (no ROM/art).
Use --check in CI; --write deliberately updates the committed fixture and hashes.
"""
import argparse, hashlib, json, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--sources',type=Path,default=ROOT.parent);p.add_argument('--host',type=Path,default=ROOT.parent/'host-source');p.add_argument('--write',action='store_true');args=p.parse_args()
sys.path.insert(0,str(args.host/'tools'))
from extract.pokemon import parse_base_stats_file,parse_evos_moves
from extract.util import parse_const_block
from extract.trainers import parse_trainer_consts,parse_parties,parse_move_choices

def lines(path):
 return [x.split(';',1)[0].strip() for x in path.read_text().splitlines()]
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in sorted(v.items()))+'}'
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return json.dumps(v)
worlds={};sources=[]
for edition,repo,gen in [('red','pokered',1),('yellow','pokeyellow',1),('gold','pokegold',2),('crystal','pokecrystal',2)]:
 src=args.sources/(repo+'-world');commit=subprocess.check_output(['git','-C',str(src),'rev-parse','HEAD'],text=True).strip()
 used=set()
 def read(rel):used.add(rel);return src/rel
 species_order=parse_const_block(read('constants/pokemon_constants.asm')); species_index={name:i for i,name in enumerate(species_order) if name}
 moves={}
 for line in lines(read('data/moves/moves.asm')):
  if not line.startswith('move '):continue
  parts=[s.strip() for s in line[5:].split(',')];id,effect,power,type,accuracy,pp=parts[:6]
  moves[id]=dict(index=len(moves)+1,name=id,effect=effect,power=int(power),type=type,accuracy=int(accuracy),pp=int(pp))
 pokemon={}
 if gen==1:
  dex_order=parse_const_block(read('constants/pokedex_constants.asm'));dex_index={name:i for i,name in enumerate(dex_order) if name}
  used.add('data/pokemon/evos_moves.asm');evos=parse_evos_moves(str(src),species_order[1:])
  for file in sorted((src/'data/pokemon/base_stats').glob('*.asm')):
   rel=file.relative_to(src).as_posix();used.add(rel);d=parse_base_stats_file(str(file),rel)
   id=d['dexConst'].removeprefix('DEX_')
   d={k:v for k,v in d.items() if k in ['baseStats','types','catchRate','baseExp','level1Moves','growthRate','tmhm']}
   d.update(index=species_index[id],dex=dex_index['DEX_'+id],name=id,**evos[id]);pokemon[id]=d
 else:
  pointers=[m.group(1) for line in lines(read('data/pokemon/evos_attacks_pointers.asm')) if (m:=re.match(r'dw (\w+)',line))]
  data={};label=None;section=0
  for line in lines(read('data/pokemon/evos_attacks.asm')):
   if re.match(r'\w+EvosAttacks:$',line):label=line[:-1];data[label]=dict(evolutions=[],levelMoves=[]);section=0
   elif label and line.startswith('db '):
    a=[s.strip() for s in line[3:].split(',')]
    if a==['0']:section+=1;continue
    if section==0:
     e=dict(method=a[0],into=a[-1])
     if a[0] in ('EVOLVE_LEVEL','EVOLVE_STAT'):e['level']=int(a[1])
     if a[0]=='EVOLVE_ITEM':e['item']=a[1]
     if a[0]=='EVOLVE_HAPPINESS':e['time']=a[1]
     data[label]['evolutions'].append(e)
    elif section==1:data[label]['levelMoves'].append(dict(level=int(a[0]),move=a[1]))
  for file in sorted((src/'data/pokemon/base_stats').glob('*.asm')):
   rel=file.relative_to(src).as_posix();used.add(rel);ls=lines(file)
   db=[[s.strip() for s in line[3:].split(',')] for line in ls if line.startswith('db ')]
   id=db[0][0];idx=species_index[id];stats=dict(zip(['hp','attack','defense','speed','specialAttack','specialDefense'],map(int,db[1])))
   tm=[];inside=False
   for line in ls:
    if line.startswith('tmhm '):inside=True;line=line[5:]
    elif not inside:continue
    elif not line:continue
    elif line.startswith(('db ','dw ','dn ','INCLUDE')):inside=False;continue
    tm.extend(s.strip().strip('\\').strip() for s in line.split(',') if s.strip().strip('\\').strip())
   growth=next(a[0][7:] for a in db if a[0].startswith('GROWTH_'))
   pokemon[id]=dict(index=idx,dex=idx,name=id,baseStats=stats,types=list(dict.fromkeys(db[2])),catchRate=int(db[3][0]),baseExp=int(db[4][0]),growthRate=growth,tmhm=tm,**data[pointers[idx-1]])
 assert len(pokemon)==(151 if gen==1 else 251),(edition,len(pokemon))
 assert len(moves)==(165 if gen==1 else 251),(edition,len(moves))
 if gen==1:
  for rel in ['constants/trainer_constants.asm','data/trainers/parties.asm','data/trainers/move_choices.asm']:read(rel)
  classes=[c for c in parse_trainer_consts(str(src)) if c!='NOBODY']
  order,parties=parse_parties(str(src));ai=parse_move_choices(str(src))
  trainers={'OPP_'+c:dict(id='OPP_'+c,index=i+1,name=c,parties=parties[order[i]],aiMods=ai[i],baseMoney=100) for i,c in enumerate(classes)}
  worlds[edition]=dict(pokemon=pokemon,moves=moves,trainers=trainers)
 else:
  classes=[m.group(1) for line in lines(read('constants/trainer_constants.asm')) if (m:=re.match(r'trainerclass\s+(\w+)',line))][1:]
  pointers=[m.group(1) for line in lines(read('data/trainers/party_pointers.asm')) if (m:=re.match(r'dw (\w+)',line))]
  groups={};group=None;party=None;kind=None
  for line in lines(read('data/trainers/parties.asm')):
   if line.endswith(':') and line[:-1] in pointers:group=line[:-1];groups[group]=[];party=None
   elif group and (m:=re.match(r'db "([^"]*)@", (TRAINERTYPE_\w+)',line)):
    kind=m.group(2);party=[];groups[group].append(dict(name=m.group(1),party=party))
   elif party is not None and line.startswith('db '):
    a=[s.strip() for s in line[3:].split(',')]
    if a==['-1']:party=None;continue
    row=dict(level=int(a[0]),species=a[1]);offset=2
    if 'ITEM' in kind:
     if a[offset]!='NO_ITEM':row['item']=a[offset]
     offset+=1
    if 'MOVES' in kind:row['moves']=[m for m in a[offset:] if m!='NO_MOVE']
    party.append(row)
  trainers={}
  for i,c in enumerate(classes):
   rows=groups.get(pointers[i],[])
   for j,row in enumerate(rows):row['id']=c+str(j+1)
   trainers[c]=dict(id=c,index=i+1,name=c,trainers=rows,baseMoney=100)
  worlds[edition]=dict(pokemon=pokemon,moves=moves,gen2Trainers=dict(classes=trainers))
 sources.append(dict(repository='pret/'+repo,revision=commit,files={rel:hashlib.sha256((src/rel).read_bytes()).hexdigest() for rel in sorted(used)}))
output='-- Native combat facts extracted from hash-pinned pret sources; no artwork or ROM data.\nreturn '+lua(worlds)+'\n'
target=ROOT/'tests/support/adaptive_native.lua';meta=ROOT/'tools/adaptive_native_references.json'
if args.write:
 target.write_text(output);meta.write_text(json.dumps(sources,indent=2)+'\n')
else:
 assert output==target.read_text(),'Native adaptive fixture differs from pinned sources'
 assert sources==json.loads(meta.read_text()),'Native adaptive reference hashes/commits differ'
print('Verified native adaptive data:',sum(len(w['pokemon']) for w in worlds.values()),'species records;',sum(len(r['files']) for r in sources),'source hashes')
