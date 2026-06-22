# FocusFlow Mac App Store 上架清单

## 前置条件

### 1. Apple Developer Program
- [ ] 注册 Apple Developer Program ($99/年): https://developer.apple.com/programs/
- [ ] 在 App Store Connect 创建 App 记录: https://appstoreconnect.apple.com
  - Bundle ID: `com.zhulei.focusflow`
  - SKU: `focusflow`
  - 平台: macOS

### 2. 证书和签名
- [ ] 在 Xcode → Settings → Accounts 中添加 Apple ID
- [ ] 创建 "Apple Distribution" 签名证书（用于 App Store 分发）
- [ ] 在 Apple Developer → Certificates 创建 "Mac App Distribution" 证书
- [ ] 创建 App Store 分发配置文件 (Provisioning Profile):
  - 类型: Mac App Store
  - Bundle ID: `com.zhulei.focusflow`
  - 名称: `FocusFlow App Store`

### 3. App Store Connect API 密钥
- [ ] 在 https://appstoreconnect.apple.com/access/api 创建 API Key
  - 类型: App Manager
  - 记下 `Key ID` 和 `Issuer ID`
  - 下载 `.p8` 密钥文件

### 3b. XcodeGen（生成 App 工程）
- [ ] 安装 XcodeGen：`brew install xcodegen`
- 项目是 SwiftPM 包，`scripts/submit_app_store.sh` 会先 `xcodegen generate` 根据 `project.yml` 生成 `FocusFlow.xcodeproj`（App 目标）再归档。生成的工程是构建产物（已 gitignore）。

### 4. 特殊权限说明
FocusFlow 使用了以下需要额外说明的权限，在 App Store Connect 的 App Review 信息中需要提供详细解释：

| 权限 | 用途 | 审核风险 |
|------|------|----------|
| `com.apple.developer.family-controls` | 专注时段屏蔽分心应用 (Screen Time API) | ⚠️ 需要充分的用途说明 |
| `com.apple.security.personal-information.calendars` | 专注时段写入 Busy 日程 | ✅ 合理用途 |
| `com.apple.security.network.client` | OAuth 登录、音效下载 | ✅ 合理用途 |
| `NSCalendarsUsageDescription` | 日历写入 | ✅ 已在 Info.plist 声明 |

### 5. Shortcuts 快捷指令依赖
- [ ] 创建两个快捷指令（用户首次启动时需安装）：
  1. `FocusFlow-Enable` — 开启专注模式
  2. `FocusFlow-Disable` — 关闭专注模式
- 或者在 App Review 备注中说明这是可选功能

## GitHub Secrets 配置

在仓库 Settings → Secrets and variables → Actions 中配置以下 Secrets（环境: `app-store`）：

| Secret 名称 | 说明 |
|------------|------|
| `DEVELOPMENT_TEAM` | Apple Developer Team ID（10位字符） |
| `APPSTORE_DISTRIBUTION_CERT_BASE64` | Apple Distribution 证书 .p12 的 Base64 |
| `APPSTORE_P12_PASSWORD` | .p12 证书密码 |
| `KEYCHAIN_PASSWORD` | CI 临时 Keychain 密码（可自设） |
| `APPSTORE_PROVISIONING_PROFILE_BASE64` | 配置文件 .mobileprovision 的 Base64 |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | .p8 密钥文件的 Base64 |

## App Store 上架信息清单

### 必需提交内容

- [ ] **App 名称**: FocusFlow
- [ ] **副标题**: 菜单栏白噪声与专注助手
- [ ] **描述**: 详细功能描述（中文 + 英文）
- [ ] **关键词**: 白噪声、专注、番茄钟、菜单栏、效率
- [ ] **技术支持网址**: (需提供)
- [ ] **隐私政策网址**: (需提供)
- [ ] **分类**: 效率 / Productivity
- [ ] **版权**: Copyright © 2026 FocusFlow

### 截图要求 (macOS)
- [ ] 至少 1 张 macOS 截图 (1280×800 或 1440×900 或 1920×1080 等 16:10/16:9)
- [ ] 建议 3-5 张：菜单栏面板、音效选择、设置界面、统计面板

### 可选但推荐
- [ ] App 预览视频 (15-30 秒)
- [ ] 宣传文本 (Promotional Text，170 字符内)
- [ ] 评级: 4+（无限制内容）

## 提交流程

### 方式一：从本机提交

```bash
# 设置环境变量
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_XXXXXX.p8"

# 执行提交
bash scripts/submit_app_store.sh
```

### 方式二：通过 GitHub Actions

1. 推送 appstore 标签触发:
   ```bash
   git tag appstore-v1.0
   git push origin appstore-v1.0
   ```

2. 或从 Actions 页面手动触发 `Submit to App Store` workflow，可选择是否上传

### 提交后

1. 等待 "Processing" 完成（通常几分钟）
2. 在 App Store Connect 完成
   - App 审核信息
   - 版本发布方式选择
3. 提交审核
4. 等待审核结果（通常 1-3 天）

## 常见拒审原因及预防

| 问题 | 预防措施 |
|------|----------|
| 功能不完整 | 确保所有声明的功能在审核版本中可用 |
| 权限使用不当 | 在 App Review 信息中清晰解释每个权限的用途 |
