# 素材来源

| 文件 | 制作方式 |
| --- | --- |
| `golden_toilet.blend` | 根据用户提供的八张参考图程序化建模，包含可编辑部件、摄影棚和金属材质 |
| `godot/assets/golden_toilet.glb` | Blender 导出的模型，保留盖子、座圈的铰链节点 |
| `godot/assets/studio.exr` | `build_model.py` 生成的灰阶灯箱环境，非下载的第三方 HDR |
| `preview.png` | Blender 离线渲染 |
| `interactive_preview.png`、`nitrogen_preview.png` | Godot 实时视口生成的截图 |
| 液流、涟漪、冷雾 | Godot 原生网格、材质、渐变纹理及粒子组成 |

参考图片未包含在发布包中。中文字体从使用者本机加载，包内没有字体文件、引擎程序或插件。Blender 模型的摄影棚贴图已内嵌，不依赖原电脑的文件位置。
