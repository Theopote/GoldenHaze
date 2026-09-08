# GoldenHaze

Iris 光影包。风格方向是温暖治愈系手绘动画光感——不追求物理写实，追求
"看起来像一帧手绘动画背景"。

## 开发原则

> **GoldenHaze 不应该把 Minecraft 截图「滤镜化成动画」，而应该重新解释
> Minecraft 世界的光、颜色和形体，使它在进入后期处理之前，就已经像一幅
> 动画背景画。**

这条原则区分 Phase 1 与 Phase 2：

| | Phase 1（当前） | Phase 2（目标） |
|---|---|---|
| 核心问题 | 原版场景 + 后期氛围 | 风格化光照 + 形体塑造 |
| 光照来源 | Vanilla lightmap | Painterly Lighting Model |
| GBuffer | scene + bright-pass | albedo / normal / material / depth |
| Bloom / God Ray | 决定画面风格的主要手段 | 最后的 10% 气氛 accent |
| 评价 | 不错的 Post Processing Prototype | 真正的吉卜力式渲染体系 |

---

## 完成度评估

整体约 **30%–40%**。方向没有走偏，但决定「是否像吉卜力」的核心模块尚未建立。

| 模块 | 评分 | 说明 |
|------|------|------|
| 风格方向 | 8/10 | 暖光冷影、非写实 tonemap 思路正确 |
| 天空 | 7/10 | 昼夜渐变 + 程序云 + 云亮/暗面分组，领先其他模块 |
| 色彩 | 6.5/10 | split-toning 有效，但目前仅依据最终像素亮度 |
| Bloom | 7/10 | 实现成熟，但权重偏高，易走向梦幻滤镜 |
| 光束 | 6/10 | 径向散射可用，应降级为辅助效果 |
| 水 | 4/10 | lightmap + 噪声闪光，缺少色块化与距离调色 |
| 植被 | 4.5/10 | 世界空间闪光方向对，但未融入 foliage shading |
| 地形 | 3/10 | `albedo * lightmap`，无自有光照模型 |
| 形体塑造 | 2/10 | 块面明暗关系仍由原版决定 |
| 空气透视 | 1/10 | 未实现 depth-based atmospheric perspective |
| 阴影系统 | 1/10 | 无 shadow map，依赖 vanilla lightmap |
| 材质统一性 | 3/10 | 各 pass 风格断裂（世界 vs 生物/手/天气） |
| 完整渲染管线 | 3/10 | GBuffer 架构停留在早期 bloom 方案 |

---

## Phase 1 已实现

以下模块方向正确，**保留并在此基础上演进**，不推倒重来：

- **暖光冷影 split-toning**（`final.fsh`）— 阴影偏冷紫、高光偏暖金
- **柔和 Bloom** — 可分离高斯模糊，bright-pass 提取
- **丁达尔光束** — `composite2` 径向采样，树叶遮挡处自然断续
- **程序化天空** — `gbuffers_skybasic`：Zenith/Horizon 色带、FBM 云、云内冷暖分组、向阳云边
- **植被闪光** — leaves block ID + 世界空间噪声亮斑（`gbuffers_terrain`）
- **水面闪光** — 世界空间噪声横向涟漪（`gbuffers_water`）
- **纸张颗粒** — `final.fsh` 采样 `textures/canvas.png`
- **非写实 tonemap** — filmic shoulder + lifted blacks

当前管线：

```
Vanilla lightmap
  → terrain/water: albedo * lightmap + sparkle accent
  → bright-pass → colortex1
  → composite / composite1: Gaussian blur (bloom)
  → composite2: god rays
  → final: tonemap + split-tone + vignette + grain
```

**局限：** 场景主体的明暗关系仍是 Minecraft 原版。即使后期调得很好，也容易得到
「Minecraft + warm cinematic shader」，而非「Minecraft 被重新解释成动画背景画」。

---

## Phase 2 路线图

按依赖顺序推进，不零散加效果：

### 2.0 — GBuffer 重构（前置条件）

```
GBUFFER
  colortex0  Scene Color / Albedo
  colortex1  Normal + Material ID
  colortex2  Auxiliary
  depthtex0  Depth

COMPOSITE
  Painterly Lighting → Atmosphere → Fog
  Bloom Extract → Bloom Blur → God Ray

FINAL
  Color Grade → Paper Texture → Vignette
```

- Bright-pass **移出** `gbuffers_terrain`，改在 composite 阶段 extract
- `colortex1` 不再被 bloom 长期占用

### 2.1 — 空气透视（P0，投入小收益大）

基于 depth 的距离雾，同时：

- 降低对比度与饱和度
- 蓝/青偏移
- 减弱远景纹理细节

### 2.2 — Painterly Lighting Model（P0，风格转折核心）

建立 `lib/PainterlyLighting.glsl`（或等效 include）：

- 3–4 个宽色阶（阴影 / 中间色 / 阳光面 / 极少数高光）
- 主动减少连续 Lambert 梯度
- 综合 sun direction、surface normal、sky visibility、depth、weather
- **不是 PBR**，是块面概括

### 2.3 — Stylized Shadow Map

- 1024/2048 shadow map，soft filtering
- 大块柔和投影，轻微暖/冷 tint
- 重点在 **shadow shape**，不在 shadow realism

### 2.4 — Foliage Rendering 2.0（最大视觉杠杆）

树是玩家最常看到的东西，应成为最重要的视觉模块：

- 树冠大块亮暗（world-space 大尺度噪声）
- 垂直色阶：顶暖黄绿 → 中自然绿 → 底蓝绿/深绿
- 向阳暖 tint / 背光青绿
- 树冠内部阴影（canopy shadow）
- 逆光边缘透光（rim translucency）
- 现有 sparkle 融入 foliage shading，而非「原版树叶 + 闪光」

### 2.5 — Water Rendering 2.0

- 水体统一 palette（天空蓝 / 青绿 / 深蓝 / 夕阳橙）
- 基于 depth 与视角的距离着色
- 动画式高光：细长横向、断续高光带，替代随机噪声亮点

### 2.6 — Cloud 2.0

从 FBM 主导转向 **Stylized Cloud Shape Model**：

- Macro blob + secondary blobs + bottom clipping + sun-side expansion
- 有限内部噪声（如 `macro 70% + medium 25% + detail 5%`）
- 强调 silhouette、mass、hard/soft edge hierarchy

### 2.7 — 统一材质 palette

grass / leaves / wood / stone / soil / water / snow 各有一套
动画背景式的色板，而非仅靠后期调色统一。

### 2.8 — 补全缺失 pass

消除风格断裂（以 Iris 当前 pipeline 支持为准）：

- `gbuffers_entities`
- `gbuffers_hand`
- `gbuffers_textured` / `gbuffers_textured_lit`
- `gbuffers_weather`
- `gbuffers_particles`

### 2.9 — 后期参数重调（最后 10%）

部分已在 Phase 1 末期预先收敛（`final.fsh` 默认值）：

- God Ray 默认 `0.45`（原 `0.9`），降级为辅助气氛
- Chroma Aberration 默认 `0.0`（原 `0.6`），可选 cinematic 效果
- Paper grain 默认 `0.35`（原 `1.0`），固定 screen-space、不 drift

Phase 2 主体完成后，再连同 Bloom 等一并重调。

---

## 目录结构

```
GoldenHaze/
└─ shaders/
   ├─ shaders.properties           # 缓冲区配置 + 可调选项
   ├─ gbuffers_terrain.vsh/.fsh   # 方块几何体
   ├─ gbuffers_water.vsh/.fsh     # 水面
   ├─ gbuffers_basic.vsh/.fsh     # 兜底 pass
   ├─ gbuffers_skybasic.vsh/.fsh  # 天空穹顶：昼夜渐变 + 程序云
   ├─ gbuffers_skytextured.vsh/.fsh # 太阳/月亮
   ├─ composite.vsh/.fsh           # Bloom 模糊 第 1 步（水平）
   ├─ composite1.vsh/.fsh          # Bloom 模糊 第 2 步（垂直）
   ├─ composite2.vsh/.fsh          # 丁达尔光束
   ├─ final.vsh/.fsh              # 合成 + tonemap + 调色 + 颗粒
   └─ textures/canvas.png         # 纸张颗粒纹理
```

Phase 2 将新增 `lib/`（共享 GLSL）、扩展 GBuffer 输出、补全 entities 等 pass。

## 如何测试

1. 安装 Fabric Loader + Fabric API + [Iris](https://irisshaders.dev/)。
2. 把 `GoldenHaze` 文件夹放进 `.minecraft/shaderpacks/`。
3. 游戏内 **视频设置 → 光影包** → 选择 GoldenHaze。
4. 找一个阳光充足、有树荫的场景——辉光与光束在亮部区域最明显；
   阴天或洞穴里效果会弱很多。

## 已知限制

- 生物 / 手部 / 天气 / 粒子等 pass 未实现（走原版 fallback，风格断裂）。
- 无 normal buffer、shadow map、depth-based lighting pipeline。
- Terrain 光照完全依赖 vanilla lightmap，无自有 Lighting Model。
- 无空气透视；split-toning 仅依据最终像素亮度，未综合法线/太阳方向等。
- 所有已实现效果的参数已接入光影设置界面，可在游戏内实时调节。

## 工具

`tools/make_canvas_texture_stdlib.py` 用纯 Python 标准库程序化生成
画布纹理（编织纹 + 纸浆斑块 + 细颗粒，无缝平铺），输出到
`shaders/textures/canvas.png`。想换一张纹理直接改随机种子重新生成即可。
