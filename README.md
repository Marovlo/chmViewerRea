# CHM Viewer RE

原生 macOS CHM 阅读器。基于对某商业 CHM 阅读器的逆向架构重建：CHMLIB（LGPL，修复版）+
WKWebView + AppKit，全部本地运行，无网络依赖。

## 功能

- **CHM 解析**：ITSF/ITSP 容器 + LZX 解压（块缓存），兼容 hhc / chmcmd 等工具生成的大档案
- **目录树**：解析 .hhc/.hhk，展开/折叠/点选跳转，行高与对齐已调校
- **目录搜索**：侧栏顶部实时过滤，结果平铺并显示章节路径；单击预览，双击退出搜索并定位
- **双向联动**：点目录跳正文；正文内翻页/跳转时目录选中项自动跟随
- **编码**：自动探测 UTF-8 / GBK（中文 CHM 免设置），工具栏可手动切换
- **侧栏**：宽度可拖拽、可折叠（⌘⌥S），进入搜索自动加宽

## 下载安装

从 [Releases](https://github.com/Marovlo/chmViewerRea/releases) 下载 zip 解压得到 `ChmViewerRe.app`。

> 应用为 **ad-hoc 签名（未公证）**，首次打开会被 Gatekeeper 拦截，任选其一解除：
>
> ```bash
> # 方法一：移除隔离属性（推荐）
> xattr -cr /path/to/ChmViewerRe.app
> ```
>
> 方法二：双击打开 → 系统设置 → 隐私与安全性 → 点击"仍要打开"。

## 构建

需要 Xcode Command Line Tools（clang / libxml2 SDK headers）。

```bash
make                                # 产出 build/ChmViewerRe.app + CLI 工具 chmtest
open build/ChmViewerRe.app 文件.chm  # 使用
```

## 验证与测试

```bash
./build/chmtest 文件.chm                        # 枚举 + TOC 树 + 内容读取冒烟测试
python3 tools/make_test_chm.py build/test.chm   # 生成无压缩测试 CHM
CHMRE_TEST=1 启动应用                            # 程序化验证搜索与目录联动
```

## 结构

```
src/             应用源码（ObjC/AppKit）
vendor/chmlib/   CHMLIB 0.40（LGPL）+ UTF-16 目录名、PMGI collation 两处修复
tools/           chmtest、测试 CHM 生成器、图标生成器
.github/         tag 推送自动构建并发布 Release
```
