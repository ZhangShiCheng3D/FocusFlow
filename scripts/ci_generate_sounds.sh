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
gen "clock_tick.aac"     60 "sine=f=1000:r=44100:d=0.03, volume=0.25"

echo "━━━ 4/6 White Noise Variants ━━━"
gen "pink_noise.aac"    120 "anoisesrc=d=120:c=pink:r=44100:a=0.25"
gen "brown_noise.aac"   120 "anoisesrc=d=120:c=brown:r=44100:a=0.25"
gen "fan.aac"           120 "anoisesrc=d=120:c=brown:r=44100:a=0.18, lowpass=f=200, highpass=f=30, volume=1.0"

echo "━━━ 5/6 Music ━━━"
gen "wind_chime.aac"    120 "sine=f=2400:r=44100:d=120, volume=0.04"
gen "piano.aac"         120 "sine=f=440:r=44100:d=120, volume=0.08"
gen "choir.aac"         120 "sine=f=330:r=44100:d=120, volume=0.06"

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
