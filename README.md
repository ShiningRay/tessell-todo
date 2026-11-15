# Tessell Todo

一个使用 [Tessell](https://github.com/ShiningRay/tessell)（Crystal retained-mode 自绘 GUI 框架）和 Tessell Kit 构建的桌面 Todo List 示例应用。

## 功能

- 添加待办事项（输入后按 Enter 或点击 Add）
- 勾选完成 / 取消完成
- 删除单条待办
- 过滤视图：All / Active / Completed
- 一键切换全部完成状态（Toggle all）
- 清除已完成项（Clear completed）
- 状态栏显示剩余/总数
- 本地 JSON 持久化（默认 `todos.json`，可用 `TESSELL_TODO_PATH` 覆盖）

## 项目结构

- `src/tessell_todo/store.cr`：纯状态与持久化逻辑（无 UI 依赖，便于测试）
- `src/tessell_todo/app.cr`：Tessell Kit 组件树与交互逻辑
- `examples/todo_demo.cr`：SDL2 + OpenGL 桌面宿主入口
- `examples/lib/kit_sdl_host.cr`：示例用 SDL 宿主（基于 Tessell 示例适配 Linux 字体路径，并增加 per-frame hook）
- `spec/store_spec.cr`：Store 单元测试

## 环境要求

- Crystal >= 1.21
- SDL2、FreeType、HarfBuzz、OpenGL 开发库
- 可用字体（通过 `TESSELL_FONT` 指定，或使用宿主默认探测路径）

Linux（Ubuntu/Debian/Arch 等，X11/Wayland）示例依赖与 Tessell 类似：

```bash
# Ubuntu/Debian
sudo apt install libsdl2-dev libfreetype6-dev libharfbuzz-dev libgl1-mesa-dev
```

## 运行

```bash
# 安装依赖（首次）
shards install

# 运行桌面 demo
TESSELL_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
  crystal run examples/todo_demo.cr
```

可选参数（由示例宿主支持）：

- `--frames=N`：渲染 N 帧后退出（用于自动化/截图）
- `--screenshot=path.png`：退出前保存截图

示例：

```bash
TESSELL_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
  crystal run examples/todo_demo.cr -- --frames=3 --screenshot=docs/screenshot.png
```

## 测试

```bash
crystal spec
```

当前包含 Store 层测试（添加/切换/删除/过滤/持久化）。UI 交互主要通过 Tessell Kit 组件与实际窗口运行验证。

## 说明

- 这是一个演示应用，用于展示如何用 Tessell Kit 组合输入框、按钮、滚动视图和自定义行组件实现常见 CRUD UI。
- 持久化为简单 JSON 文件写入，适合 demo，不面向高并发或复杂数据场景。

## License

MIT
