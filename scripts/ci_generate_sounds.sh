#!/usr/bin/env bash
# ============================================================
# FocusFlow CI 音效生成脚本
# 在 GitHub Actions macOS runner 上运行
# 生成 24 个 .aac 音效文件到 sounds-out/
# ============================================================
set -euo pipefail

OUT="sounds-out"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "=== FocusFlow Sound Generator (CI) ==="
echo "Output: $OUT"
echo ""

# ────────────────────────────────────────────
# 辅助函数: 用 ffmpeg 合成音效
# ────────────────────────────────────────────
gen() {
  local name="$1"
  local duration="$2"
  shift 2
  if [ -f "$OUT/$name" ]; then
    echo "  SKIP $name (exists)"
    return 0
  fi
  ffmpeg -y -nostdin -loglevel error -f lavfi -i "$@" \
         -t "$duration" -c:a aac -b:a 128k "$OUT/$name"
  echo "  OK   $name"
}

echo "━━━ 1/6 White Noise ━━━"
gen "white_noise.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.25"

echo "━━━ 2/6 Nature & Water ━━━"
gen "rain_light.aac"    120 "anoisesrc=d=120:c=white:r=44100:a=0.30, highpass=f=2000, lowpass=f=8000, volume=0.6"
gen "rain_heavy.aac"    120 "anoisesrc=d=120:c=white:r=44100:a=0.42, highpass=f=1200, lowpass=f=10000, volume=1.1"
gen "thunder.aac"       120 "anoisesrc=d=120:c=brown:r=44100:a=0.55, lowpass=f=250, volume=0.8"
gen "ocean_wave.aac"    120 "anoisesrc=d=120:c=pink:r=44100:a=0.35, lowpass=f=1000, highpass=f=60, volume=0.7"
gen "stream.aac"        120 "anoisesrc=d=120:c=white:r=44100:a=0.22, highpass=f=900, lowpass=f=7000, volume=0.5"
gen "waterfall.aac"     120 "anoisesrc=d=120:c=white:r=44100:a=0.48, lowpass=f=8000, volume=1.2"
gen "campfire.aac"      120 "anoisesrc=d=120:c=pink:r=44100:a=0.28, highpass=f=150, lowpass=f=3500, volume=0.55"
gen "forest_bird.aac"   120 "anoisesrc=d=120:c=pink:r=44100:a=0.10, highpass=f=2000, lowpass=f=8000, volume=0.3"

echo "━━━ 3/6 Urban ━━━"
gen "cafe.aac"          120 "anoisesrc=d=120:c=pink:r=44100:a=0.12, lowpass=f=2000, volume=0.25"
gen "library.aac"       120 "anoisesrc=d=120:c=brown:r=44100:a=0.06, lowpass=f=800, volume=0.15"
gen "keyboard.aac"       60 "anoisesrc=d=60:c=white:r=44100:a=0.15, highpass=f=600, lowpass=f=4000, volume=0.3"
# Periodic 30ms pulse once per second — a real tick. A short `sine d=0.03`
# source EOFs at 30ms and `-t` cannot extend it, so the old version produced
# a ~0.03s file that looped into a buzz instead of a clock tick.
gen "clock_tick.aac"     60 "aevalsrc=0.25*sin(2*PI*1000*t)*lt(mod(t\,1)\,0.03):d=120:s=44100"

echo "━━━ 4/6 White Noise Variants ━━━"
gen "pink_noise.aac"    120 "anoisesrc=d=120:c=pink:r=44100:a=0.25"
gen "brown_noise.aac"   120 "anoisesrc=d=120:c=brown:r=44100:a=0.25"
gen "fan.aac"           120 "anoisesrc=d=120:c=brown:r=44100:a=0.18, lowpass=f=200, highpass=f=30, volume=1.0"

echo "━━━ 5/6 Music ━━━"
# These used to be a single constant sine tone each (a drone, not music).
# Now additive-synth patches: chords with harmonics + envelope/vibrato.
# wind_chime: 3 pentatonic bells (C5/E5/G5) struck every 2/3/5s with decay.
gen "wind_chime.aac"    120 "aevalsrc=0.6*sin(2*PI*523.25*t)*exp(-4*mod(t\,2)):d=120:s=44100[a];aevalsrc=0.6*sin(2*PI*659.25*t)*exp(-4*mod(t\,3)):d=120:s=44100[b];aevalsrc=0.6*sin(2*PI*783.99*t)*exp(-4*mod(t\,5)):d=120:s=44100[c];[a][b][c]amix=inputs=3:normalize=0,volume=0.4"
# piano: C-E-G chord, each note = fundamental + harmonics, with slow tremolo.
gen "piano.aac"         120 "aevalsrc=(0.5*sin(2*PI*261.63*t)+0.25*sin(2*PI*523.25*t)+0.12*sin(2*PI*784.0*t))*(0.85+0.15*sin(2*PI*0.2*t)):d=120:s=44100[a];aevalsrc=(0.5*sin(2*PI*329.63*t)+0.25*sin(2*PI*659.25*t)+0.12*sin(2*PI*988.0*t))*(0.85+0.15*sin(2*PI*0.2*t)):d=120:s=44100[b];aevalsrc=(0.5*sin(2*PI*392.0*t)+0.25*sin(2*PI*784.0*t))*(0.85+0.15*sin(2*PI*0.2*t)):d=120:s=44100[c];[a][b][c]amix=inputs=3:normalize=0,volume=0.16"
# choir: A-C#-E vocal-pad chord with per-voice vibrato (slight detune in rate).
gen "choir.aac"         120 "aevalsrc=0.5*sin(2*PI*220.0*(1+0.006*sin(2*PI*5*t))*t):d=120:s=44100[a];aevalsrc=0.45*sin(2*PI*277.18*(1+0.006*sin(2*PI*5.3*t))*t):d=120:s=44100[b];aevalsrc=0.45*sin(2*PI*329.63*(1+0.006*sin(2*PI*4.7*t))*t):d=120:s=44100[c];[a][b][c]amix=inputs=3:normalize=0,volume=0.22"

echo "━━━ 6/6 Special ━━━"
gen "train.aac"         120 "anoisesrc=d=120:c=brown:r=44100:a=0.28, lowpass=f=400, volume=0.5"
gen "spaceship.aac"     120 "sine=f=70:r=44100:d=120, volume=0.12"
gen "japanese_garden.aac" 120 "anoisesrc=d=120:c=pink:r=44100:a=0.10, highpass=f=400, lowpass=f=4000, volume=0.25"
gen "night_cricket.aac" 120 "anoisesrc=d=120:c=pink:r=44100:a=0.08, highpass=f=3000, lowpass=f=9000, volume=0.2"
gen "seagull.aac"       120 "anoisesrc=d=120:c=pink:r=44100:a=0.10, highpass=f=1000, lowpass=f=5000, volume=0.2"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Generated $(ls -1 "$OUT"/*.aac 2>/dev/null | wc -l) / 24 files"
echo "Output: $OUT"
ls -lh "$OUT"/*.aac 2>/dev/null | awk '{print "  "$5"  "$NF}'
