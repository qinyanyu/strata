# Prompt sweep in the community-report shape: 3 fresh prompts each of about 4,096 / 32,768 / 128,000 tokens with a
# 256-token cap, through tools/strata_bench.py's own request, prompt and digest code (thinking off, temperature 0).
#   python3 sweep.py http://127.0.0.1:8080 OUT.json
import json,statistics,sys,time
sys.path.insert(0,'/opt/strata/tools')
import strata_bench as sb
base=sys.argv[1];out_path=sys.argv[2]
suite=sb.Suite(base,'',262144,3,False)
suite.calibrate()
results={}
for target in (4096,32768,128000):
    rows=[]
    for run in range(3):
        d=sb.digest(sb.chat(base,'',suite.prompt_for(target,run),256))
        rows.append(d)
        print('%6d run %d: prompt %s tokens %.1f tok/s, first token %.2f s, decode %s tok/s over %s tokens'%(
            target,run+1,d['prompt_tokens'],d['prompt_tps'] or 0,d['ttft_s'] or 0,d['decode_tps'],d['generated_tokens']),flush=True)
    results[str(target)]=rows
    json.dump({'date':time.strftime('%Y-%m-%d %H:%M'),'cap':256,'runs':results},open(out_path,'w'),indent=1)
print('done')
