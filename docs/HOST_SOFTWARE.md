# PyQt6 上位机代码说明

上位机入口为 `host/main.py`，负责串口控制和 UDP RGB565 图传，不在电脑端执行 FPGA 图像算法。

## 核心参数

| 常量 | 默认值 | 说明 |
| --- | ---: | --- |
| `UDP_IP` | `0.0.0.0` | 监听全部本地网卡 |
| `UDP_PORT` | `8080` | UDP 图传目标端口 |
| `IMG_W` / `IMG_H` | `1024` / `600` | FPGA 输出有效画面尺寸 |
| `FRAME_SIZE` | `1,228,800` 字节 | 单帧 RGB565 数据长度 |
| `FPS` | `30` | 录像目标帧率 |

## 函数与类职责

| 名称 | 职责 |
| --- | --- |
| `_resource_path()` | 兼容源码运行与 PyInstaller 打包后的资源路径 |
| `_clear_frame_queue()` | 算法切换时清除旧帧，防止跨算法残帧 |
| `receive_network_stream()` | 接收 UDP 分片，以源端口 8191 识别新帧并拼接 RGB565 帧 |
| `VideoProcessorThread` | 后台解码 RGB565 → BGR888，处理截图和录像，避免阻塞 GUI |
| `VideoRasterWidget` | 使用 `QPainter` 绘制最新视频帧并保持画面比例 |
| `VisionControllerWidget` | 构建算法菜单、管理串口并发送 `AA main sub 55` 命令 |
| `EthernetVideoWidget` | 管理实时监看、截图、录像和图传页状态 |
| `MainDashboard` | 组合全局导航、算法页、图传页和窗口行为 |

## 并发与缓存

UDP 接收循环运行在守护线程中，完整帧放入容量为 3 的 `frame_queue`。队列满时优先移除旧帧，以实时性优先于逐帧完整性。`VideoProcessorThread` 从队列取帧并完成 NumPy/OpenCV 解码，GUI 线程仅消费最新 `QImage`，避免信号积压造成延迟。

算法切换时，`stream_resync_event` 请求接收线程丢弃未完成帧，直到再次收到源端口 8191 的帧起点。该行为必须与 FPGA 端 UDP 发送协议保持一致。

## 算法配置维护

`VisionControllerWidget.algo_config` 是上位机算法名称和模式编码的维护入口。每项结构为：

```python
(英文名称, 中文名称, 直接模式或 None, 子模式菜单或 None)
```

新增或修改模式时必须同时检查：

1. `host/main.py` 的 `algo_config`。
2. 对应工程的 `uart_cmd_parser.v`。
3. 对应工程的 `video_algo_manager.v` 与 `top.v`。
4. `docs/ALGORITHM_INDEX.md` 的模式映射表。

