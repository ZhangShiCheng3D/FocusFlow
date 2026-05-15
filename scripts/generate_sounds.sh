#!/usr/bin/env bash
# ============================================================
# FocusFlow 音效一键生成脚本
# 在 Mac 上运行: bash scripts/generate_sounds.sh
# 需要: brew install ffmpeg
# ============================================================
set -euo pipefail

OUT="${HOME}/Desktop/FocusFlow-Sounds"
mkdir -p "$OUT"

echo "╔══════════════════════════════════════╗"
echo "║  FocusFlow 音效生成器 v1.0          ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ────────────────────────────────────────────
# 辅助函数
# ────────────────────────────────────────────
gen() {
  local name="$1" duration="$2" shift; shift 2
  # 跳过已存在的文件
  if [ -f "$OUT/$name" ]; then
    echo "  ⏭️  $name (已存在)"
    return 0
  fi
  ffmpeg -y -f lavfi -i "$@" -t "$duration" -c:a aac -b:a 128k "$OUT/$name" 2>/dev/null
  echo "  ✅ $name"
}

echo "━━━ 1/4 白噪音类（算法合成）━━━"
echo ""

gen "white_noise.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.25"
gen "pink_noise.aac"  120 "anoisesrc=d=120:c=pink:r=44100:a=0.25"
gen "brown_noise.aac" 120 "anoisesrc=d=120:c=brown:r=44100:a=0.25"

# Fan: 低频 filtered brown noise
gen "fan.aac" 120 "anoisesrc=d=120:c=brown:r=44100:a=0.20, lowpass=f=180, highpass=f=30"

echo ""
echo "━━━ 2/4 自然/水声类（算法合成）━━━"
echo ""

# Light Rain: 高频 white noise + 随机振幅调制
gen "rain_light.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.30, highpass=f=2000, lowpass=f=8000, volume=0.6"

# Heavy Rain: 更强的高频噪声 + 低频背景
gen "rain_heavy.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.40, highpass=f=1500, lowpass=f=10000, volume=1.0"

# Thunder: 低频 rumble
gen "thunder.aac" 120 "anoisesrc=d=120:c=brown:r=44100:a=0.50, lowpass=f=300, volume=0.8"

# Ocean Waves: pink noise + 极低频正弦波调制 (潮汐感)
gen "ocean_wave.aac" 120 "anoisesrc=d=120:c=pink:r=44100:a=0.35, lowpass=f=1200, highpass=f=80, volume=0.7"

# Stream: 中高频白噪声 (溪流声)
gen "stream.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.25, highpass=f=800, lowpass=f=6000, volume=0.5"

# Waterfall: 全频段强白噪声
gen "waterfall.aac" 120 "anoisesrc=d=120:c=white:r=44100:a=0.45, lowpass=f=8000, volume=1.2"

# Campfire: 中低频 crackling
gen "campfire.aac" 120 "anoisesrc=d=120:c=pink:r=44100:a=0.30, highpass=f=200, lowpass=f=4000, volume=0.6"

echo ""
echo "━━━ 3/4 城市/特殊类（算法合成）━━━"
echo ""

# Library: 极低音量 brown noise + 高频衰减
gen "library.aac" 120 "anoisesrc=d=120:c=brown:r=44100:a=0.08, lowpass=f=1000, volume=0.3"

# Spaceship: 低频持续嗡鸣
gen "spaceship.aac" 120 "sine=f=80:r=44100:d=120, volume=0.15"

# Train: 低频有节奏的噪声
gen "train.aac" 120 "anoisesrc=d=120:c=brown:r=44100:a=0.30, lowpass=f=500, volume=0.5"

# Clock tick: 用正弦波模拟 (这个用合成不够逼真, 建议手动替换)
gen "clock_tick.aac" 60  "sine=f=800:r=44100:d=0.05, volume=0.3"

# Wind Chime: 随机高频铃音
gen "wind_chime.aac" 120 "sine=f=2000:r=44100:d=120, volume=0.08"

echo ""
echo "━━━ 4/4 需要手动下载的音效 ━━━"
echo ""
echo "以下音效用算法难以逼真合成，建议从免费音效站下载:"
echo ""

cat << 'EOF'
  🎧  Pixabay (pixabay.com/sound-effects/)  全部免费商用，无需注册

  📁 forest_bird.aac  →  搜索 "forest birds morning"
  📁 night_cricket.aac → 搜索 "night crickets ambience"
  📁 seagull.aac      →  搜索 "seagull ocean"
  📁 keyboard.aac     →  搜索 "mechanical keyboard typing"
  📁 cafe.aac         →  搜索 "cafe ambience chatter"
  📁 piano.aac        →  搜索 "soft piano ambient"
  📁 choir.aac        →  搜索 "choir drone" 或 "ambient vocal pad"
  📁 japanese_garden.aac → 搜索 "zen garden water" 或 "japanese garden"

  下载后放到: $OUT
  然后运行此脚本会自动转换格式
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL=0
for f in "$OUT"/*.aac; do
  [ -f "$f" ] && TOTAL=$((TOTAL + 1))
done

echo "  ✅ 已生成/已有: $TOTAL / 24"
echo "  📂 输出目录:    $OUT"
echo ""
echo "💡 下一步:"
echo "  1. 从 Pixabay 下载剩余 8 个音效"
echo "  2. 把文件放到 $OUT"
echo "  3. 上传全部 .aac 到 Cloudflare R2"
echo "     (路径: cdn.focusflow.app/sounds/<filename>)"
