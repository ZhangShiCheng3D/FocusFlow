#!/usr/bin/env bash
# ============================================================
# FocusFlow 音效下载脚本
# 在 Mac 上运行: bash scripts/download_sounds.sh
# 需要先安装: brew install ffmpeg
# ============================================================
set -euo pipefail

SOUNDS_DIR="${HOME}/Desktop/FocusFlow-Sounds"
mkdir -p "$SOUNDS_DIR"
cd "$SOUNDS_DIR"

echo "=== FocusFlow 音效下载器 ==="
echo "保存到: $SOUNDS_DIR"
echo ""

# ────────────────────────────────────────────
# 来源 1: Pixabay (免费商用, 无需注册)
# 在浏览器打开以下链接，手动下载
# ────────────────────────────────────────────
cat << 'EOF'

┌──────────────────────────────────────────────────────┐
│                                                      │
│  📢 下载指南                                         │
│                                                      │
│  方式 A：Pixabay (推荐，免费商用)                    │
│  1. 打开 https://pixabay.com/sound-effects/         │
│  2. 逐个搜索以下关键词，下载 MP3/WAV                │
│  3. 把文件放到 ~/Desktop/FocusFlow-Sounds/          │
│  4. 重新运行此脚本自动转换为 AAC                    │
│                                                      │
│  方式 B：Mixkit (免费商用)                           │
│  1. 打开 https://mixkit.co/free-sound-effects/      │
│  2. 搜索 "ambient" "rain" "ocean" "white noise"    │
│  3. 下载 .wav 文件                                  │
│                                                      │
│  方式 C：Zapsplat (免费, 需注册)                    │
│  1. https://www.zapsplat.com/sound-effect-category/ │
│  2. 注册免费账号即可下载                            │
│                                                      │
│  方式 D：一键下载 (noise 类音效)                     │
│  白噪音等可用 ffmpeg 直接生成，见下方               │
│                                                      │
└──────────────────────────────────────────────────────┘

EOF

# ────────────────────────────────────────────
# 用 ffmpeg 直接生成白噪音类音效（无需下载）
# ────────────────────────────────────────────

echo "正在生成白噪音/噪声音效..."

# White noise (60s loop)
ffmpeg -y -f lavfi -i "anoisesrc=d=60:c=white:r=44100:a=0.3" \
       -c:a aac -b:a 128k -t 60 "white_noise.aac" 2>/dev/null && echo "  ✓ white_noise.aac"

# Pink noise (60s loop)
ffmpeg -y -f lavfi -i "anoisesrc=d=60:c=pink:r=44100:a=0.3" \
       -c:a aac -b:a 128k -t 60 "pink_noise.aac" 2>/dev/null && echo "  ✓ pink_noise.aac"

# Brown noise (60s loop)
ffmpeg -y -f lavfi -i "anoisesrc=d=60:c=brown:r=44100:a=0.3" \
       -c:a aac -b:a 128k -t 60 "brown_noise.aac" 2>/dev/null && echo "  ✓ brown_noise.aac"

# Fan noise (低频噪声模拟风扇)
ffmpeg -y -f lavfi -i "anoisesrc=d=60:c=brown:r=44100:a=0.2, \
       lowpass=f=200" -c:a aac -b:a 128k -t 60 "fan.aac" 2>/dev/null && echo "  ✓ fan.aac"

echo ""
echo "=== 已生成 4 个噪声音效 ==="
echo ""
echo "⏳ 剩余 17 个自然/城市/音乐音效需要从网上下载"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 下载清单（搜索关键词 → 文件名）:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat << 'EOF'
  🌧️  自然类:
       "heavy rain loop"      → rain_heavy.aac
       "thunder ambience"     → thunder.aac
       "ocean waves loop"     → ocean_wave.aac
       "stream water flow"    → stream.aac
       "waterfall ambience"   → waterfall.aac
       "campfire crackling"   → campfire.aac
       "forest birds morning" → forest_bird.aac
       "night crickets loop"  → night_cricket.aac
       "seagull ocean birds"  → seagull.aac

  🏙️  城市类:
       "library ambience"     → library.aac
       "keyboard typing"      → keyboard.aac
       "clock ticking"        → clock_tick.aac

  🎵  音乐类:
       "wind chimes gentle"   → wind_chime.aac
       "soft piano ambient"   → piano.aac
       "choir drone ambience" → choir.aac

  ✨  特殊类:
       "train ambience"       → train.aac
       "spaceship hum drone"  → spaceship.aac
       "japanese garden"      → japanese_garden.aac

  ℹ️  免费音效:
       "light rain"           → rain_light.aac
       "cafe ambience"        → cafe.aac
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 推荐下载网站:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  • Pixabay:    https://pixabay.com/sound-effects/"
echo "  • Mixkit:     https://mixkit.co/free-sound-effects/ambient/"
echo "  • Zapsplat:   https://www.zapsplat.com/"
echo "  • Freesound:  https://freesound.org/ (需注册)"
echo ""

# ────────────────────────────────────────────
# 格式转换工具: 把下载的 mp3/wav 转成 aac
# ────────────────────────────────────────────
cat << 'SCRIPT' > "$SOUNDS_DIR/convert_to_aac.sh"
#!/usr/bin/env bash
# 将当前目录所有 wav/mp3 转为 aac (60s loop, 128k)
set -euo pipefail
for f in *.wav *.mp3 2>/dev/null; do
  [ -f "$f" ] || continue
  out="${f%.*}.aac"
  echo "Converting: $f → $out"
  ffmpeg -y -stream_loop 0 -i "$f" -t 60 -c:a aac -b:a 128k "$out" 2>/dev/null
done
echo "Done!"
SCRIPT
chmod +x "$SOUNDS_DIR/convert_to_aac.sh"

echo "✅ 脚本完成!"
echo "📂 音效保存在: $SOUNDS_DIR"
echo "💡 下载完其他音效后, 运行 convert_to_aac.sh 转换格式"
