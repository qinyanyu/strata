#!/bin/bash
# DeepSeek V4.1-Flash on the RTX 4090 Laptop (16 GB), 94 GiB RAM, Strata 0.2.7 (main 5e8a4cca), DeepSeek engine 0.1.52 package.
# Each config: tools/strata_bench.py --long (its own server, temperature 0, thinking off) and three coding answers with
# thinking on (the model's own sampling, a fresh server).  The two default configs also get the October script
# (benchmark_ds.py: 4K/32K/128K/250K x3).  Servers on 127.0.0.1 only.
#  1-3. 2.25 bpw: default (Faster, DSpark auto) / Full quality (--experts 6) / DSpark forced on
#  4.   tools/dsv41/tune.py --mode quick on a copy of the config
#  5.   October script on 2.25 default
#  6.   setup 2.00 bpw (138 GB download; Engram and drafter shared)
#  7-8. 2.00 bpw default: strata_bench + coding, October script
#  9.   2.25 default again (drift check after the 2.00 runs)
set -u
cd <strata> || exit 1
OUT=~/strata-bench-deepseek-2026-10-27
CFG=$OUT/configs
MON=bench/results/2026-09-30-community-rtx-5090/monitor.py
CODE=<scratch>/ds-code.py
cp "$CODE" $OUT/ds-code.py
URL=http://127.0.0.1:8080

stop_server() {
  pkill -f 'serve/[s]erver.py'
  for i in $(seq 1 180); do pgrep -f '[s]trata-dsv41' >/dev/null || return 0; sleep 1; done
  echo "engine still running after 180 s"; pkill -f '[s]trata-dsv41'; sleep 5
}
start_server() {  # config, outdir
  .venv/bin/python serve/server.py --engine strata --config "$1" --port 8080 > "$2/server.out" 2>&1 &
  local T0=$(date +%s)
  while :; do
    curl -s --max-time 3 $URL/health | grep -q '"loaded": true' && { echo "  ready after $(( $(date +%s) - T0 )) s"; return 0; }
    pgrep -f 'serve/[s]erver.py' >/dev/null || { echo "  server exited"; tail -20 "$2/server.out"; return 1; }
    [ $(( $(date +%s) - T0 )) -gt 1800 ] && { echo "  not ready after 1800 s"; return 1; }
    sleep 2
  done
}
snap() {  # label, outdir
  echo "$1 $(date +%T) profile=$(powerprofilesctl get 2>/dev/null) no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo) max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq) vram_used_mib=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) mem_available_kib=$(awk '/MemAvailable/{print $2}' /proc/meminfo) cached_kib=$(awk '/^Cached/{print $2}' /proc/meminfo) load=$(cut -d' ' -f1-3 /proc/loadavg)" >> "$2/snapshots.txt"
}
englog() {  # config -> its engine log path
  .venv/bin/python -c "import json,sys; print(json.load(open(sys.argv[1]))['log'])" "$1"
}
quick() {  # name, config
  local D=$OUT/$1; mkdir -p "$D"; cp "$2" "$D/config.json"
  local LOG=$(englog "$2"); touch "$LOG"; local L0=$(wc -l < "$LOG")
  echo "== $1: strata_bench --long $(date +%T)"
  snap before "$D"
  .venv/bin/python $MON "$D/telemetry.jsonl" & local M=$!
  .venv/bin/python tools/strata_bench.py --config "$2" --long --out "$D/strata-bench" > "$D/strata-bench.out" 2>&1
  echo "  strata_bench exit $? $(date +%T)"
  stop_server
  echo "== $1: coding with thinking $(date +%T)"
  if start_server "$2" "$D"; then
    snap after-load "$D"
    .venv/bin/python $OUT/ds-code.py $URL "$D/code.jsonl" "$1" > "$D/code.out" 2>&1
    echo "  coding exit $? $(date +%T)"
    snap after-code "$D"
  fi
  stop_server
  kill $M
  sed -n "$((L0+1)),\$p" "$LOG" > "$D/engine.log"
}
october() {  # name, config
  local D=$OUT/$1; mkdir -p "$D"; cp "$2" "$D/config.json"
  local LOG=$(englog "$2"); touch "$LOG"; local L0=$(wc -l < "$LOG")
  local PACK=$(.venv/bin/python -c "import json,sys; a=json.load(open(sys.argv[1]))['args']; print(a[a.index('--pack')+1])" "$2")
  echo "== $1: October script 4K/32K/128K/250K x3 $(date +%T)"
  if start_server "$2" "$D"; then
    snap after-load "$D"
    .venv/bin/python $MON "$D/telemetry.jsonl" & local M=$!
    .venv/bin/python $OUT/benchmark_ds.py --root . --pack "$PACK" --url $URL --out "$D" \
      --targets 4096,32768,128000,250000 > "$D/benchmark.out" 2>&1
    echo "  benchmark exit $? $(date +%T)"
    kill $M
    snap after-bench "$D"
  fi
  stop_server
  sed -n "$((L0+1)),\$p" "$LOG" > "$D/engine.log"
}

echo "start $(date)"
stop_server
quick ds225-faster $CFG/ds225-faster.json
quick ds225-full $CFG/ds225-full.json
quick ds225-dspark $CFG/ds225-dspark.json

echo "== tune (quick) on a copy $(date +%T)"
mkdir -p $OUT/tune; cp $CFG/ds225-tune.json $OUT/tune/config-before.json
.venv/bin/python tools/dsv41/tune.py --config $CFG/ds225-tune.json --mode quick > $OUT/tune/tune.out 2>&1
echo "  tune exit $? $(date +%T)"; cp $CFG/ds225-tune.json $OUT/tune/config-after.json
stop_server

october ds225-faster-october $CFG/ds225-faster.json

echo "== setup 2.00 bpw $(date +%T)"
./setup.sh --setup --yes --family deepseek41 --model IST-DAS-2.00bpw --context 262144 --no-start < /dev/null \
  > ~/strata-setup-deepseek-2.00-2026-10-27.log 2>&1
echo "  setup exit $? $(date +%T)"
stop_server
if [ -f strata-deepseek-v4.1-flash-ist-das-2.00bpw.json ]; then
  cp strata-deepseek-v4.1-flash-ist-das-2.00bpw.json $CFG/ds200-faster.json
  quick ds200-faster $CFG/ds200-faster.json
  october ds200-faster-october $CFG/ds200-faster.json
fi
quick ds225-faster-again $CFG/ds225-faster.json
echo "end $(date)"
