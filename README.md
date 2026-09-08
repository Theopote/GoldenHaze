# GoldenHaze

Iris 光影包。风格方向是温暖治愈系手绘动画光感——不追求物理写实，追求
"看起来像一帧手绘动画背景"。

## 开发原则

> **GoldenHaze 不应该把 Minecraft 截图「滤镜化成动画」，而应该重新解释
> Minecraft 世界的光、颜色和形体，使它在进入后期处理之前，就已经像一幅
> 动画背景画。**

这条原则区分 Phase 1 与 Phase 2：

| | Phase 1（已完成基础） | Phase 2（当前） |
|---|---|---|
| 核心问题 | 原版场景 + 后期氛围 | 风格化光照 + 形体塑造 |
| 光照来源 | Vanilla lightmap | Sun + Sky + Bounce 三光源 |
| GBuffer | scene + bright-pass | colortex0 场景 + colortex1 法线/材质 |
| Bloom / God Ray | 曾主导画面风格 | 语义 bloom + 辅助光柱（10% accent） |
| 定位 | Post Processing Prototype | Painterly animation-background renderer |

---

## 完成度评估

整体约 **70%–80%**。Phase 2 核心模块已落地；剩余为 god-ray 深度遮挡、deferred 光照迁移、gbuffers_line 等扩展。

| 模块 | 评分 | 说明 |
|------|------|------|
| 风格方向 | 8.5/10 | Painterly 宽色阶 + 三光源，非 Toon/Cel |
| GBuffer 2.0 | 8/10 | colortex1 = normal + material；colortex2/3 = bloom/godray |
| 光照 | 7.5/10 | Sun/Sky/Bounce + lightmap 作可见性信息 |
| 空气透视 | 7.5/10 | depthtex0 驱动 haze / 去饱和 / 远景柔化 |
| 植被 | 7.5/10 | Canopy mass + 风相控 shimmer |
| 水 | 7.5/10 | 四层模型：底色 / 天空反射 / 光带 / 微闪 |
| 材质色板 | 8/10 | 8 组 block.properties + palette.glsl |
| 阴影 | 6.5/10 | 1024² + 3×3 PCF，冷色投影 tint |
| Bloom | 7.5/10 | 语义材质权重，抑制雪地/石材误发光 |
| 调试 | 7/10 | DEBUG_VIEW 0–8（5/6 为 proxy） |
| 实体覆盖 | 8/10 | MAT_ENTITY + 完整 pass 链 |

---

## 架构对照（23 点清单）

| # | 要求 | 状态 |
|---|------|------|
| 1 | GBuffer 2.0：colortex1 不再被 bloom 占用 | ✅ |
| 2 | terrain/water 传递 worldNormal + viewNormal | ✅ |
| 3 | 克制 Painterly GBuffer（非 PBR） | ✅ |
| 4 | lightmap = sky/block 可见性，非最终颜色 | ✅（weather pass 已改） |
| 5 | 三光源：Sun / Sky / Bounce | ✅ `lib/painterly.glsl` |
| 6 | 宽 smoothstep 光照分段 | ✅ |
| 7 | 非 Toon（无描边/海报化） | ✅ |
| 8 | Water 法线 + 视角天空 tint | ✅ |
| 9 | Water 四层模型 | ✅ `lib/water.glsl` |
| 10 | Foliage 风相控 shimmer | ✅ gust gate |
| 11 | Canopy mass | ✅ |
| 12 | block.properties 材质组 1–8 | ✅ |
| 13 | GoldenHaze Palette System | ✅ |
| 14 | final.fsh 过时 TODO 清理 | ✅ |
| 15 | Semantic Bloom | ✅ `lib/bloom.glsl` |
| 16 | God-ray 深度遮挡 | ⏳ P2（暂不实现） |
| 17 | 空气透视 | ✅ |
| 18 | Shadow 1024 + 轻量 PCF | ✅ |
| 19 | 完整管线架构 | ✅ forward painterly + composite post |
| 20 | Phase 2.1–2.9 | ✅ |
| 21 | DEBUG_VIEW 0–8 | ✅（5/6 为场景 proxy） |
| 22 | shaders.properties 分组 UI | ✅ |
| 23 | README 与实现一致 | ✅ 本节 |

**刻意不做（P3）：** SSR、PBR、SSGI、PCSS、TAA、DOF、motion blur 等写实特性。

---

## Phase 2 稳定化（进行中）

### Lib include 层级

```
gbuffer.glsl          — MAT_*、pack/unpack、readMaterialId、isSkyMaterial
├── palette.glsl
├── shadow.glsl
├── painterly.glsl    — Sun / Sky / Bounce（palette + shadow）
├── atmospheric.glsl
├── bloom.glsl        — 语义 bloom（不依赖 atmospheric）
└── debug.glsl
```

所有 lib 文件使用 `#ifndef GOLDENHAZE_*` guard，避免 `final.fsh` 等多 include 路径重定义。

### 法线空间约定

| 用途 | 空间 |
|------|------|
| GBuffer 编码、NdotL 太阳光、阴影、Fresnel、逆光 rim | **viewNormal** |
| Sky 填充、Bounce、树冠顶/底色阶、水面水平光带 | **worldNormal** |

混用 view/world 会导致转头时色块漂移——稳定化阶段已统一。

### 已修 P0

- `readMaterialId` / `isSkyMaterial` 归位 `gbuffer.glsl`（`composite.fsh` 可独立编译）

---

## 渲染管线

```
GBUFFER STAGE (forward painterly)
  colortex0  lit scene
  colortex1  view-normal + material ID
  depthtex0  depth

COMPOSITE
  composite   semantic bloom extract (scene + GBuffer → colortex2)
  composite1/2 bloom blur
  composite3  god rays → colortex3

FINAL
  atmosphere + bloom + godray + grade + grain
  DEBUG_VIEW 1–8 可选
```

**局限：** 光照仍在 gbuffers forward 路径（非 composite deferred）；god-ray 尚无 depth 遮挡。

---

## Phase 2 路线图

按依赖顺序推进，不零散加效果：

### 2.0 — GBuffer 重构 ✅（已完成）

```
GBUFFER
  colortex0  Scene Color
  colortex1  Normal + Material ID   ← lib/gbuffer.glsl
  colortex2  Bloom working buffer
  colortex3  God-ray accumulation

COMPOSITE
  composite   Bloom extract
  composite1  Bloom blur (H)
  composite2  Bloom blur (V)
  composite3  God rays

FINAL
  Color Grade → Paper Texture → Vignette
```

- Bright-pass 已移出 gbuffers，改在 `composite.fsh` extract
- `colortex1` 专用于 GBuffer，不再被 bloom 占用
- 材质 ID：`MAT_DEFAULT` … `MAT_GLASS`（见 `lib/gbuffer.glsl`）
- `worldNormal` + `viewNormal` 已在 terrain / water / entities pass 传递

### 2.1 — 空气透视 ✅（已完成）

在 `final.fsh` 读取 `depthtex0` + `colortex1`（跳过天空材质）：

- 基于线性视空间深度的 haze（`ATMOSPHERE_START` / `ATMOSPHERE_END`）
- 向地平线色调混合（昼夜 / 日落 / 雨天联动 `sunPosition`）
- 降低饱和度与对比度
- 远景 4-tap 柔化，减弱方块纹理细节

实现：`lib/atmospheric.glsl`

### 2.2 — Painterly Lighting Model ✅（已完成）

`lib/painterly.glsl`，在 gbuffers 阶段替换 `albedo * lightmap`：

- **三光源**：Sun（暖色时段 tint）+ Sky（冷色半球填充）+ Bounce（地面反射艺术欺骗）
- 3 段宽色阶：冷阴影 → 中性中间 → 暖阳光（`NdotL` + `sunPosition`）
- `lmcoord` → `skyVis` / `blockVis`（可见性信息，非最终颜色）
- 滑块：`SUN_STRENGTH`、`SKY_STRENGTH`、`BOUNCE_STRENGTH`、`PAINTERLY_STRENGTH`

### 2.3 — Stylized Shadow Map ✅（已完成）

- `shadow.vsh/fsh` + `shadow_water` — 地形/水面投射阴影
- `lib/shadow.glsl` — 透视畸变 + 3×3 软 PCF + 坡度 bias
- 接入 `shadePainterly()`：仅户外太阳光受阴影影响，火把/洞穴 ambient 不受影响
- 投影区冷紫蓝 tint（`stylizedShadowTint`），最低亮度保留 ~32% 避免死黑
- `shaders.properties`：`shadowMapResolution=1024`，`shadowDistance=128`
- 滑块：`SHADOW_STRENGTH`、`SHADOW_SOFTNESS`

待办：`shadow_entities`、树叶半透明投影

### 2.4 — Foliage Rendering 2.0 ✅（已完成）

`lib/foliage.glsl`，在 `gbuffers_terrain` 对 `MAT_FOLIAGE` 后处理：

- **树冠体积明暗** — world-space 大尺度噪声亮/暗团块
- **垂直色阶** — 顶面暖黄绿、中间自然绿、底面蓝绿（法线 + 弱 world-Y）
- **向阳 / 背光** — 暖黄绿 vs 青绿分色
- **树冠内部阴影** — sky light 遮挡 + 密度噪声压暗
- **逆光 rim 透光** — 背光边缘黄绿透光
- **闪光** — 集成进 foliage pass，仅亮部树冠团块出现
- 滑块：`FOLIAGE_STRENGTH`（可回混纯 painterly）

### 2.5 — Water Rendering 2.0 ✅（已完成）

`lib/water.glsl`，在 `gbuffers_water` 后处理：

- **四层水体** — 底色 palette / 天空反射 Fresnel / 横向光带 / 微闪
- 洞穴/无天空光处保持暗水色
- 滑块：`WATER_STRENGTH`、`WATER_DIST_NEAR`、`WATER_DIST_FAR`、`SHIMMER_STRENGTH`（高光带）

### 2.6 — Cloud 2.0 ✅（已完成）

`lib/cloud.glsl`，替换 `gbuffers_skybasic` 中的 5-octave FBM：

- **分层形体** — macro 70% + medium 25% + detail 5%
- **大轮廓** — `smoothstep` 离散团块，干净天空间隙
- **底部裁切** — 大尺度 base height，cumulus 平底
- **向阳扩展** — 太阳方向偏移采样，金边 rim
- **边缘层级** — 硬 silhouette + 软内部 mass
- 保留昼夜/日落云调色与 `CLOUD_COVERAGE` 滑块

### 2.7 — 统一材质 palette ✅（已完成）

`lib/palette.glsl` + 扩展 `block.properties`：

| block ID | 材质 | 色板特征 |
|----------|------|----------|
| 1 | 树叶 | 黄绿 / 蓝绿光影（+ Foliage 2.0） |
| 2 | 草 | 暖黄绿 |
| 3 | 木材 | 暖琥珀 / 紫褐阴影 |
| 4 | 石材 | 冷灰蓝 / 奶油高光 |
| 5 | 土壤 | 暖赭 / 红褐 |
| 6 | 雪 | 冷蓝阴影 / 明亮高光 |
| 7 | 陶瓦 | 暖橙 / 红褐阴影 |
| 8 | 玻璃 | 冷蓝透明调 |
| — | 水 | `lib/water.glsl`（gbuffers_water） |

- `applyMaterialPalette()` — 光照前 albedo 色偏
- `materialPaletteBands()` — painterly 光影色阶统一来源
- 滑块：`PALETTE_STRENGTH`

### 2.8 — 补全 entities 相关 pass ✅

**`MAT_ENTITY` 专用色板**（暖色动画角色调）+ 完整 pass 覆盖：

| Pass | 内容 |
|------|------|
| `gbuffers_entities` | 不透明生物 |
| `gbuffers_entities_translucent` | 史莱姆等半透明生物 |
| `gbuffers_block` / `block_translucent` | 箱子、告示牌等方块实体 |
| `gbuffers_hand` / `hand_water` | 手部与手持透明物 |
| `gbuffers_spidereyes` | 蜘蛛/末影人/龙眼发光 |
| `gbuffers_armor_glint` | 附魔金色闪光 |
| `gbuffers_lightning` | 闪电与龙息光束 |
| `gbuffers_particles_translucent` | 半透明粒子 |
| `shadow_entities` | 生物投影 |

共享实现：`lib/gbuffers_pass.glsl`（`writeEntityGbuffer` 等）

### 2.9 — 后期参数重调（最后 10%）✅

Phase 2 手绘管线（光照 / 材质 / 大气）已承担主风格，后期只做 accent，不再主导画面。

| 参数 | 原默认 | 新默认 | 说明 |
|------|--------|--------|------|
| `BLOOM_STRENGTH` | 0.80 | **0.50** | 场景已有 painterly 高光与 foliage sparkle |
| `BLOOM_THRESHOLD` | 0.55 | **0.62** | 仅最亮区域（太阳、水面、眼睛）进入 bloom |
| `GODRAY_STRENGTH` | 0.45 | **0.32** | 进一步降级为辅助气氛 |
| `GODRAY_EXPOSURE` | 0.50 | **0.40** | 光柱累积更柔和 |
| `GODRAY_DENSITY` | 0.85 | **0.75** | 采样步长略松，减少硬边 |
| `WARMTH` | 1.00 | **0.85** | 调色板已偏暖，split-tone 略收 |
| `VIGNETTE_STRENGTH` | 0.60 | **0.42** | 暗角更轻，避免压暗手绘色阶 |
| `GRAIN_STRENGTH` | 0.35 | **0.25** | 纸纹更 subtle |
| `SHIMMER_STRENGTH` | 1.00 | **0.75** | foliage / 水面闪点配合更高 bloom 阈值 |
| `CHROMA_STRENGTH` | 0.60 | **0.00** | 可选 cinematic，默认关闭 |

其他收敛（Phase 1 末期 + 2.9）：

- Paper grain 固定 screen-space、不 drift
- `final.fsh` 雨天削弱 bloom / god-ray（`weatherFade`）
- tonemap 肩部 `0.65`、softCurve 抬升 `0.022`，配合更低 bloom 保持通透

**游戏内验收清单：**

1. 正午林地 — bloom 只在树冠亮边与水面，不糊全局
2. 日出 / 日落 — god-ray 可见但不盖过云与大气雾
3. 雨天 — 光柱与 bloom 明显减弱
4. 洞穴 / 夜间 — vignette 不压死暗部色阶
5. 实体眼睛 / 闪电 — 仍有局部 bloom，但整体不刺眼

---

## 目录结构

```
GoldenHaze/
└─ shaders/
   ├─ shaders.properties           # 缓冲区配置 + 可调选项
   ├─ lib/gbuffer.glsl            # GBuffer 编码：法线 + 材质 ID
   ├─ lib/painterly.glsl          # 宽色阶手绘光照模型
   ├─ lib/foliage.glsl            # 树冠体积着色（Foliage 2.0）
   ├─ lib/water.glsl              # 风格化水体（Water 2.0）
   ├─ lib/palette.glsl             # 统一材质色板（Phase 2.7）
   ├─ lib/cloud.glsl              # 分层形体云（Cloud 2.0）
   ├─ lib/atmospheric.glsl        # 空气透视
   ├─ lib/bloom.glsl              # 语义 bloom 材质权重
   ├─ lib/debug.glsl              # DEBUG_VIEW 0–8
   ├─ lib/shadow.glsl             # 风格化阴影采样
   ├─ lib/gbuffers_pass.glsl        # 共享 entity/hand/particle 输出
   ├─ shadow.vsh/.fsh             # 阴影贴图 pass
   ├─ shadow_water.vsh/.fsh       # 水面阴影
   ├─ shadow_entities.vsh/.fsh    # 生物阴影
   ├─ gbuffers_terrain.vsh/.fsh   # 方块几何体
   ├─ gbuffers_water.vsh/.fsh     # 水面
   ├─ gbuffers_entities.vsh/.fsh
   ├─ gbuffers_entities_translucent.vsh/.fsh
   ├─ gbuffers_block.vsh/.fsh
   ├─ gbuffers_block_translucent.vsh/.fsh
   ├─ gbuffers_hand.vsh/.fsh
   ├─ gbuffers_hand_water.vsh/.fsh
   ├─ gbuffers_spidereyes.vsh/.fsh
   ├─ gbuffers_armor_glint.vsh/.fsh
   ├─ gbuffers_lightning.vsh/.fsh
   ├─ gbuffers_textured.vsh/.fsh
   ├─ gbuffers_textured_lit.vsh/.fsh
   ├─ gbuffers_weather.vsh/.fsh   # 雨雪
   ├─ gbuffers_particles.vsh/.fsh
   ├─ gbuffers_particles_translucent.vsh/.fsh # 粒子
   ├─ gbuffers_basic.vsh/.fsh     # 兜底 pass
   ├─ gbuffers_skybasic.vsh/.fsh  # 天空穹顶：昼夜渐变 + 程序云
   ├─ gbuffers_skytextured.vsh/.fsh # 太阳/月亮
   ├─ composite.vsh/.fsh           # Bloom bright-pass extract
   ├─ composite1.vsh/.fsh          # Bloom 模糊（水平）
   ├─ composite2.vsh/.fsh          # Bloom 模糊（垂直）
   ├─ composite3.vsh/.fsh          # 丁达尔光束
   └─ final.vsh/.fsh              # 合成 + tonemap + 调色 + 颗粒
   └─ textures/canvas.png         # 纸张颗粒纹理
```

Phase 2 核心模块已全部落地；后续扩展：god-ray depth 遮挡、gbuffers_line、deferred 光照迁移。

### DEBUG_VIEW 模式

在光影设置 → **Debug** 中调节 `DEBUG_VIEW`：

| 值 | 显示 |
|----|------|
| 0 | 最终画面 |
| 1 | GBuffer 法线 |
| 2 | 深度 |
| 3 | 材质 ID 色码 |
| 4 | NdotL（向阳分面） |
| 5 | 天空光 proxy |
| 6 | 方块光 proxy |
| 7 | 大气 haze |
| 8 | Bloom mask |

## 如何测试

1. 安装 Fabric Loader + Fabric API + [Iris](https://irisshaders.dev/)。
2. 把 `GoldenHaze` 文件夹放进 `.minecraft/shaderpacks/`。
3. 游戏内 **视频设置 → 光影包** → 选择 GoldenHaze。
4. 找一个阳光充足、有树荫的场景——辉光与光束在亮部区域最明显；
   阴天或洞穴里效果会弱很多。

## 已知限制

- `gbuffers_line`（钓鱼线、选中方块轮廓）仍 fallback 到 `gbuffers_basic`。
- 所有已实现效果的参数已接入光影设置界面，可在游戏内实时调节。

## 工具

`tools/make_canvas_texture_stdlib.py` 用纯 Python 标准库程序化生成
画布纹理（编织纹 + 纸浆斑块 + 细颗粒，无缝平铺），输出到
`shaders/textures/canvas.png`。想换一张纹理直接改随机种子重新生成即可。
