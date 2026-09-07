# GoldenHaze

Iris 光影包骨架,风格方向是温暖治愈系手绘动画的那种光感——大片柔和辉光、
暖色高光/冷色阴影的分离配色(split-toning)、以及淡淡的画布颗粒感。
不追求写实,追求"看起来像一帧手绘动画截图"。

## 目录结构

```
GoldenHaze/
└─ shaders/
   ├─ shaders.properties        # 缓冲区配置 + 可调选项
   ├─ gbuffers_terrain.vsh/.fsh # 方块几何体：应用原版光照贴图 + 提取高光区域
   ├─ gbuffers_water.vsh/.fsh   # 半透明几何体，逻辑同 terrain
   ├─ gbuffers_basic.vsh/.fsh   # 兜底 pass
   ├─ gbuffers_skybasic.vsh/.fsh    # 天空穹顶：昼夜渐变 + fbm 大云朵
   ├─ gbuffers_skytextured.vsh/.fsh # 太阳/月亮：暖色染色 + 写入辉光缓冲
   ├─ composite.vsh/.fsh        # 辉光模糊 第1步（水平方向 9-tap 高斯）
   ├─ composite1.vsh/.fsh       # 辉光模糊 第2步（垂直方向，完成模糊）
   ├─ composite2.vsh/.fsh       # 丁达尔光束（朝太阳屏幕位置径向采样）
   └─ final.vsh/.fsh            # 合成辉光+光束 + tonemap + 暖色调色 + 暗角
```

## 渲染管线现状

1. `gbuffers_terrain` / `water` / `basic` 用原版的 lightmap(方块光+天空光)
   给场景上色,同时做一次亮度阈值提取,把"够亮"的区域(阳光直射的树叶、
   火把、天空)单独写进 `colortex1`,作为辉光的原料。
2. `composite` → `composite1` 是一个标准的可分离高斯模糊(先横后竖),
   把 `colortex1` 里的高光区域越晕越开,做出辉光效果。
3. `composite2` 以太阳的屏幕坐标为中心,对模糊后的亮部缓冲做径向采样
   叠加,生成阳光穿透树叶的丁达尔光束(被树叶遮挡处光束自然断续)。
4. `final` 把辉光和光束叠加回场景,先做柔和 tonemap 防止高光死白,
   再做暖色分离调色(阴影偏冷紫、高光偏暖金)、暗角和颗粒。

天空由 `gbuffers_skybasic`(昼夜渐变 + fbm 程序云,云随时间漂移、
向阳边缘镶金边)和 `gbuffers_skytextured`(太阳/月亮暖色染色并写入
辉光缓冲)两个 pass 接管。

## 如何测试

1. 安装 Fabric Loader + Fabric API + [Iris](https://irisshaders.dev/)。
2. 把 `GoldenHaze` 文件夹放进 `.minecraft/shaderpacks/`。
3. 游戏内 视频设置 → 光影包 → 选择 GoldenHaze。
4. 找一个阳光充足、有树荫的场景效果最明显——辉光阈值是针对"够亮的
   区域"设计的,阴天或洞穴里效果会很弱。

## 已知限制 / 下一步

- 生物/手部/天气等 pass 未实现(走原版 fallback,不参与辉光提取)。
- 所有已实现效果的参数都已接入光影设置界面,可在游戏内实时调节。

## 工具

`tools/make_canvas_texture_stdlib.py` 用纯 Python 标准库程序化生成
画布纹理(编织纹 + 纸浆斑块 + 细颗粒,无缝平铺),输出到
`shaders/textures/canvas.png`。想换一张纹理直接改随机种子重新生成即可。

详细开发任务拆解见同目录下的 `CURSOR_PROMPT.md`。
