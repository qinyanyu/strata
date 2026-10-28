# Operator notes

The runner's hardware probe reported the GPU as "AMD Radeon" and left the
driver, VRAM, power limit and storage null. Filled in from the host;
`README.md`, `results.json` and `outputs.jsonl` are the runner's output and are
unchanged.

- GPU: AMD Radeon RX 7900 XT, 20,455 MiB VRAM (20 GiB class), `gfx1100`,
  Navi 31, PCI `1002:744c`; `amdgpu` driver in kernel 7.2.8-9-omarchy.
- Power limit: 257 W (`power1_cap`), not changed for the run. The card was at
  about 62 °C after the run.
- Runtime: the runner reports ROCm 7.2.4; the engine is the 0.1.52 `rx7900`
  release package.
- Storage: the model files are on `/dev/mapper/omarchy_root` (499 GiB, 42% used);
  storage performance was not measured.
- Profile: `lazy_load` was set false and `idle_unload_s` 0 in a copy of the
  installed run config only so the benchmark starts with a freshly loaded engine
  and stays loaded; the engine arguments are unchanged.
  `server_requests_before_run` is 0 in `results.json`.
- Six of the nine performance requests reached the 512-token cap (all 4K/16K).
  The 4K first-answer sample is n=1 (12.96 s) and the 16K sample is n=2
  (19.12 s median); the other capped requests were still reasoning at the cap.
  The short requests completed.
- Model revisions were not provided; `results.json` records them as null with a
  reason.
- The desktop session (Omarchy/Hyprland) was active; no other inference
  clients were running.
