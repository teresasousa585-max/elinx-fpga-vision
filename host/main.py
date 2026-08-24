"""2026 年集创赛国奖项目 FPGA 实时视觉处理系统上位机。

通过串口向 FPGA 发送算法切换命令，并接收 UDP RGB565 视频流，提供
实时预览、截图和录像功能。电脑端只负责控制与显示，所有图像算法均在
FPGA 中执行。协议参数和模式编码必须与对应 FPGA 工程保持一致。
"""

import sys
import os
import time
import socket
import cv2
import numpy as np
import threading
import queue
import ctypes
import re
import serial
import serial.tools.list_ports
from datetime import datetime

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, QWidget,
    QPushButton, QComboBox, QLabel, QMessageBox, QGridLayout,
    QStackedWidget, QFrame, QFileDialog, QSizePolicy, QGraphicsOpacityEffect
)
from PyQt6.QtGui import QCursor, QIcon, QImage, QPainter, QColor, QGuiApplication, QFont
from PyQt6.QtCore import (
    Qt, QThread, QVariantAnimation, QEasingCurve, QTimer, pyqtSignal, QRectF, QPropertyAnimation
)


# ============================================================
# 1. 协议与图像参数
# ============================================================
# 网络协议参数：FPGA 将 RGB565 分片发送到 UDP 8080；源端口 8191
# 作为新帧起点标记，具体拼帧规则见 receive_network_stream()。
UDP_IP = "0.0.0.0"
UDP_PORT = 8080

# 视频格式参数：每像素 16 位，因此单帧字节数为宽 × 高 × 2。
# 修改分辨率或像素格式时，必须同步修改 FPGA 端 UDP 发送长度和显示时序。
IMG_W = 1024
IMG_H = 600
FRAME_SIZE = IMG_W * IMG_H * 2
FPS = 30
def _resource_path(name):
    # PyInstaller 打包后资源在 _MEIPASS 临时目录；开发时回退到脚本所在目录。
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, name)

ICON_PATH = _resource_path("elinx.png")

# 小队列优先保证实时性；网络抖动时丢弃旧帧，避免显示延迟持续累积。
frame_queue = queue.Queue(maxsize=3)

# 在算法切换进入图传时请求一次重新同步，避免旧算法残帧混入新画面。
stream_resync_event = threading.Event()

def _clear_frame_queue():
    while True:
        try:
            frame_queue.get_nowait()
        except queue.Empty:
            break


# ============================================================
# 2. 透明桌面 UI 基础组件
# ============================================================
class TransparentRule(QFrame):
    """轻微蓝色透明底 + 细边框。"""
    def __init__(self, parent=None, radius=16):
        super().__init__(parent)
        self.setObjectName("TransparentRule")
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.setStyleSheet(f"""
            QFrame#TransparentRule {{
                background: rgba(24, 36, 78, 62);
                border: 1px solid rgba(178, 202, 255, 54);
                border-radius: {radius}px;
            }}
        """)


class WindowDot(QPushButton):
    def __init__(self, color, hover_color, parent=None):
        super().__init__(parent)
        self.setFixedSize(13, 13)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {color};
                border: none;
                border-radius: 6px;
            }}
            QPushButton:hover {{ background-color: {hover_color}; }}
        """)


class TransparentTitleBar(QWidget):
    def __init__(self, window):
        super().__init__(window)
        self.window_ref = window
        self._drag_offset = None
        self.setFixedHeight(48)
        self.setStyleSheet("background: rgba(15, 24, 54, 72); border: none;")

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 0, 14, 0)
        layout.setSpacing(9)

        btn_close = WindowDot("#FF5F57", "#FF766F")
        btn_min = WindowDot("#FFBD2E", "#FFCB57")
        btn_max = WindowDot("#28C840", "#48D85D")
        btn_close.clicked.connect(window.close)
        btn_min.clicked.connect(window.showMinimized)
        btn_max.clicked.connect(window.toggle_maximize)

        layout.addWidget(btn_close)
        layout.addWidget(btn_min)
        layout.addWidget(btn_max)
        layout.addSpacing(8)

        title = QLabel("FPGA Vision")
        title.setStyleSheet("""
            QLabel {
                background: transparent;
                color: rgba(255,255,255,235);
                font-size: 14px;
                font-weight: 700;
            }
        """)
        layout.addWidget(title)
        layout.addStretch()


    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and not self.window_ref.is_manual_maximized():
            self._drag_offset = event.globalPosition().toPoint() - self.window_ref.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if self._drag_offset is not None and (event.buttons() & Qt.MouseButton.LeftButton):
            self.window_ref.move(event.globalPosition().toPoint() - self._drag_offset)
            event.accept()

    def mouseReleaseEvent(self, event):
        self._drag_offset = None
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.window_ref.toggle_maximize()
            event.accept()


class SideNavButton(QPushButton):
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setCheckable(True)
        self.setMinimumHeight(42)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: 1px solid transparent;
                border-radius: 11px;
                color: rgba(255,255,255,180);
                text-align: left;
                padding: 9px 12px;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton:hover {
                background: rgba(116,140,255,24);
                border-color: rgba(176,202,255,42);
                color: white;
            }
            QPushButton:checked {
                background: rgba(72,105,230,58);
                border-color: rgba(150,180,255,88);
                color: white;
            }
        """)


class AlgorithmButton(QPushButton):
    """算法按钮：轻微 ACTIVE 状态 + 右上角小徽标。"""
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self._active = False
        self.setProperty("active", False)

    def set_active(self, active):
        active = bool(active)
        if self._active == active:
            return
        self._active = active
        self.setProperty("active", active)
        self.style().unpolish(self)
        self.style().polish(self)
        self.update()

    def paintEvent(self, event):
        super().paintEvent(event)
        if not self._active:
            return

        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        font = QFont(self.font())
        base_pt = font.pointSizeF()
        if base_pt <= 0:
            base_pt = 10.0
        font.setPointSizeF(max(8.5, base_pt * 0.56))
        font.setBold(True)
        painter.setFont(font)

        text = "● ACTIVE"
        fm = painter.fontMetrics()
        tw = fm.horizontalAdvance(text)
        th = fm.height()
        pad_x, pad_y = 8, 4
        rect = QRectF(
            self.width() - tw - pad_x * 2 - 12,
            10,
            tw + pad_x * 2,
            th + pad_y * 2,
        )
        painter.setPen(QColor(176, 205, 255, 210))
        painter.setBrush(QColor(74, 105, 220, 58))
        painter.drawRoundedRect(rect, 8, 8)
        painter.drawText(rect, Qt.AlignmentFlag.AlignCenter, text)


class RecentAlgoButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.algorithm_key = None
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setMinimumHeight(34)
        self.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: 1px solid transparent;
                border-radius: 9px;
                color: rgba(255,255,255,155);
                text-align: left;
                padding: 7px 10px;
                font-size: 12px;
                font-weight: 600;
            }
            QPushButton:hover {
                background: rgba(96,124,240,26);
                border-color: rgba(170,198,255,38);
                color: rgba(255,255,255,230);
            }
        """)


class ToastOverlay(QFrame):
    """右下角无打扰 Toast。成功操作自动淡入并在 1.5 秒后消失。"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ToastOverlay")
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        self.setStyleSheet("""
            QFrame#ToastOverlay {
                background: rgba(17, 29, 62, 215);
                border: 1px solid rgba(166, 196, 255, 82);
                border-radius: 13px;
            }
            QLabel#ToastText {
                background: transparent;
                color: rgba(255,255,255,238);
                font-size: 13px;
                font-weight: 600;
            }
        """)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(13, 10, 15, 10)
        layout.setSpacing(9)

        self.dot = QLabel("●")
        self.dot.setStyleSheet("background: transparent; color: #79A7FF; font-size: 12px;")
        self.label = QLabel("")
        self.label.setObjectName("ToastText")
        self.label.setWordWrap(False)
        layout.addWidget(self.dot)
        layout.addWidget(self.label)

        self.effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.effect)
        self.effect.setOpacity(0.0)
        self.hide()

        self._hide_timer = QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.timeout.connect(self._fade_out)
        self._anim = None

    def show_message(self, text, kind="info", duration=1500):
        self.label.setText(text)
        if kind == "success":
            self.dot.setStyleSheet("background: transparent; color: #69D993; font-size: 12px;")
        else:
            self.dot.setStyleSheet("background: transparent; color: #79A7FF; font-size: 12px;")

        self.adjustSize()
        self._reposition()
        self.raise_()
        self.show()
        self._hide_timer.stop()
        self._animate_opacity(self.effect.opacity(), 1.0, 160)
        self._hide_timer.start(duration)

    def _animate_opacity(self, start, end, duration):
        if self._anim is not None:
            self._anim.stop()
        self._anim = QPropertyAnimation(self.effect, b"opacity", self)
        self._anim.setDuration(duration)
        self._anim.setStartValue(start)
        self._anim.setEndValue(end)
        self._anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        self._anim.start()

    def _fade_out(self):
        if self._anim is not None:
            self._anim.stop()
        self._anim = QPropertyAnimation(self.effect, b"opacity", self)
        self._anim.setDuration(220)
        self._anim.setStartValue(self.effect.opacity())
        self._anim.setEndValue(0.0)
        self._anim.setEasingCurve(QEasingCurve.Type.InCubic)
        self._anim.finished.connect(self.hide)
        self._anim.start()

    def _reposition(self):
        parent = self.parentWidget()
        if parent is None:
            return
        margin = 26
        self.move(
            max(margin, parent.width() - self.width() - margin),
            max(margin, parent.height() - self.height() - margin),
        )

    def reposition(self):
        if self.isVisible():
            self.adjustSize()
            self._reposition()


# ============================================================
# 3. UDP 视频接收与帧同步
# ============================================================
def receive_network_stream():
    """持续接收 UDP 分片，并按源端口标记拼接完整 RGB565 帧。"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024 * 100)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(2.0)
    sock.bind((UDP_IP, UDP_PORT))

    frame_buffer = bytearray()
    waiting_for_frame_start = False
    print(f"📡 网络接收子线程已启动，监听端口 {UDP_PORT}...")

    while True:
        try:
            # 算法刚切换时，不让旧算法残留数据继续参与下一帧拼接。
            if stream_resync_event.is_set():
                frame_buffer.clear()
                _clear_frame_queue()
                waiting_for_frame_start = True
                stream_resync_event.clear()

            data, addr = sock.recvfrom(65535)

            # 重新同步期间，仅从协议规定的新帧起点（源端口 8191）开始接收。
            if waiting_for_frame_start:
                if addr[1] != 8191:
                    continue
                waiting_for_frame_start = False

            # 源端口 8191 表示新帧起点；先提交上一帧，再缓存当前分片。
            if addr[1] == 8191:
                if len(frame_buffer) > 0 and len(frame_buffer) != FRAME_SIZE:
                    print(f"⚠️ 丢包警告：残帧长度 {len(frame_buffer)}，已丢弃")
                frame_buffer.clear()

            frame_buffer.extend(data)

            # 单次只提交一帧，避免异常超长数据包触发连续切片并放大延迟。
            if len(frame_buffer) >= FRAME_SIZE:
                raw_frame = frame_buffer[:FRAME_SIZE]
                frame_buffer = frame_buffer[FRAME_SIZE:]

                if frame_queue.full():
                    try:
                        frame_queue.get_nowait()
                    except queue.Empty:
                        pass
                frame_queue.put(raw_frame)

        except socket.timeout:
            continue
        except Exception as e:
            print(f"❌ 网络异常: {e}")
            break


# ============================================================
# 4. RGB565 解码、预览、截图与录像
# ============================================================
class VideoProcessorThread(QThread):
    """在后台线程中解码 RGB565 帧并执行截图、录像任务。"""
    snapshot_saved = pyqtSignal(str)

    def __init__(self, default_save_dir):
        super().__init__()
        self._run_flag = True
        self.is_recording = False
        self.take_snapshot = False
        self.video_writer = None
        self.save_directory = default_save_dir

        self._latest_bgr = None
        self._latest_lock = threading.Lock()
        self._decoded_frames = 0
        self._last_frame_time = 0.0

    @property
    def decoded_frames(self):
        return self._decoded_frames

    @property
    def last_frame_time(self):
        return self._last_frame_time

    def take_latest_frame(self):
        with self._latest_lock:
            frame = self._latest_bgr
            self._latest_bgr = None
        return frame

    def clear_latest_frame(self):
        with self._latest_lock:
            self._latest_bgr = None

    def run(self):
        while self._run_flag:
            try:
                raw_frame = frame_queue.get(timeout=0.1)

                # 按 RGB565 位域展开到 8 位 BGR，供 OpenCV 与 Qt 使用。
                img_16 = np.frombuffer(raw_frame, dtype='<u2').reshape((IMG_H, IMG_W))
                img_bgr = np.empty((IMG_H, IMG_W, 3), dtype=np.uint8)
                img_bgr[..., 0] = (img_16 << 3) & 0xF8
                img_bgr[..., 1] = (img_16 >> 3) & 0xFC
                img_bgr[..., 2] = (img_16 >> 8) & 0xF8

                if self.take_snapshot:
                    filename = datetime.now().strftime("snapshot_%Y%m%d_%H%M%S.jpg")
                    filepath = os.path.join(self.save_directory, filename)
                    saved_ok = cv2.imwrite(filepath, img_bgr)
                    self.take_snapshot = False
                    if saved_ok:
                        self.snapshot_saved.emit(filepath)

                # 录像统一写入 BGR 帧，保持与 OpenCV VideoWriter 的接口一致。
                if self.is_recording:
                    if self.video_writer is None:
                        filename = datetime.now().strftime("record_%Y%m%d_%H%M%S.avi")
                        filepath = os.path.join(self.save_directory, filename)
                        fourcc = cv2.VideoWriter_fourcc(*'XVID')
                        self.video_writer = cv2.VideoWriter(filepath, fourcc, FPS, (IMG_W, IMG_H))
                    self.video_writer.write(img_bgr)
                else:
                    if self.video_writer is not None:
                        self.video_writer.release()
                        self.video_writer = None

                # 只保留最新帧：不排队、不改帧、不重新拼接
                with self._latest_lock:
                    self._latest_bgr = img_bgr

                self._decoded_frames += 1
                self._last_frame_time = time.monotonic()

            except queue.Empty:
                pass
            except Exception as e:
                print(f"❌ 视频处理异常: {e}")

    def stop(self):
        self._run_flag = False
        if self.video_writer is not None:
            self.video_writer.release()
            self.video_writer = None
        self.wait(2000)


# ============================================================
# 5. 原始像素画布
# ============================================================
class VideoRasterWidget(QWidget):
    """直接绘制 QImage，并按窗口比例居中缩放视频画面。"""
    """
    透明顶层窗口下使用普通 QWidget 绘制视频。
    不创建 QPixmap、不做 scaled() 临时图，也不嵌 QOpenGLWidget，
    可避免 Windows 透明窗口 + OpenGL 子窗口常见的闪烁/黑块/残影。
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self._frame_ref = None
        self._image = QImage()
        self._hud_text = ""
        self.setMinimumSize(520, 320)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WidgetAttribute.WA_OpaquePaintEvent, False)
        self.setStyleSheet("background: transparent; border: none;")

    def set_bgr_frame(self, frame):
        if frame is None or frame.size == 0:
            return

        # 保留 numpy 帧对象，确保 QImage 使用的底层内存整个绘制周期都有效。
        self._frame_ref = frame
        h, w, ch = frame.shape
        self._image = QImage(
            frame.data,
            w,
            h,
            frame.strides[0],
            QImage.Format.Format_BGR888
        )
        self.update()

    def clear_frame(self):
        self._frame_ref = None
        self._image = QImage()
        self.update()

    def set_hud_text(self, text):
        self._hud_text = text or ""
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, False)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)

        # 只有视频画布保留稳定黑底，避免 KeepAspectRatio 空白处透出桌面。
        painter.fillRect(self.rect(), QColor(0, 0, 0, 220))

        if self._image.isNull():
            painter.setPen(QColor(255, 255, 255, 135))
            painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, "等待视频流接入...")
            return

        iw, ih = self._image.width(), self._image.height()
        ww, wh = self.width(), self.height()
        if iw <= 0 or ih <= 0 or ww <= 0 or wh <= 0:
            return

        scale = min(ww / iw, wh / ih)
        dw = int(iw * scale)
        dh = int(ih * scale)
        x = (ww - dw) // 2
        y = (wh - dh) // 2
        painter.drawImage(QRectF(x, y, dw, dh), self._image)

        # 极简 HUD：只保留画面左下角当前算法名称。
        if self._hud_text:
            hud_font = QFont(self.font())
            base_pt = hud_font.pointSizeF()
            if base_pt <= 0:
                base_pt = 11.0
            hud_font.setPointSizeF(max(10.0, base_pt * 0.92))
            hud_font.setBold(True)
            painter.setFont(hud_font)
            fm = painter.fontMetrics()
            tw = fm.horizontalAdvance(self._hud_text)
            th = fm.height()
            px, py = 10, 6
            bx = x + 14
            by = y + dh - th - py * 2 - 14
            badge = QRectF(bx, by, tw + px * 2, th + py * 2)
            painter.setPen(QColor(180, 208, 255, 155))
            painter.setBrush(QColor(10, 20, 48, 160))
            painter.drawRoundedRect(badge, 9, 9)
            painter.setPen(QColor(248, 250, 255, 238))
            painter.drawText(badge, Qt.AlignmentFlag.AlignCenter, self._hud_text)


# ============================================================
# 6. 页面过渡动画
# ============================================================
class TransitionOverlay(QWidget):
    def __init__(self, parent, pix_curr, pix_next, is_forward):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        self.resize(parent.size())
        self.pix_curr = pix_curr
        self.pix_next = pix_next
        self.is_forward = is_forward
        self.progress = 0.0

    def set_progress(self, value):
        self.progress = value
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        travel = self.width() * 0.018
        curr_x = -(travel * self.progress) if self.is_forward else travel * self.progress
        next_x = travel * (1.0 - self.progress) if self.is_forward else -travel * (1.0 - self.progress)
        painter.setOpacity(1.0 - self.progress)
        painter.drawPixmap(int(curr_x), 0, self.pix_curr)
        painter.setOpacity(self.progress)
        painter.drawPixmap(int(next_x), 0, self.pix_next)


class AppleTransitionStackedWidget(QStackedWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.is_animating = False

    def switch_to(self, index):
        if self.is_animating or index == self.currentIndex():
            self.setCurrentIndex(index)
            return

        self.is_animating = True
        old_idx = self.currentIndex()
        old_widget = self.currentWidget()
        pix_old = old_widget.grab()

        self.setCurrentIndex(index)
        new_widget = self.widget(index)
        new_widget.setGeometry(self.rect())
        pix_new = new_widget.grab()
        new_widget.hide()

        self.overlay = TransitionOverlay(self, pix_old, pix_new, index > old_idx)
        self.overlay.show()

        self.anim = QVariantAnimation(self)
        self.anim.setDuration(260)
        self.anim.setStartValue(0.0)
        self.anim.setEndValue(1.0)
        self.anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.anim.valueChanged.connect(self.overlay.set_progress)
        self.anim.finished.connect(lambda: self._finish_switch(new_widget))
        self.anim.start()

    def _finish_switch(self, new_widget):
        new_widget.show()
        self.overlay.deleteLater()
        self.is_animating = False


# ============================================================
# 7. 算法与串口控制页
# ============================================================
class VisionControllerWidget(QWidget):
    """维护算法菜单、串口连接和四字节控制命令。"""
    request_ethernet_switch = pyqtSignal()
    toast_requested = pyqtSignal(str, str)
    algorithm_used = pyqtSignal(str, str)
    active_algorithm_changed = pyqtSignal(str)
    serial_status_changed = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.ser = None
        self._algorithm_registry = {}
        self._active_algorithm_key = None
        self._active_buttons = []
        self._serial_idle_text = "○ 未连接"
        self._serial_flash_token = 0
        # 保存进入图传前的算法页，确保返回操作保留用户上下文。
        self._video_return_page = None
        self._video_return_page_prepared = False

        # 算法配置项格式：
        # (英文标识, 中文显示名, (主模式, 子模式) 或 None, 子菜单或 None)。
        # 主模式 0~10 对应基础工程；增强工程复用主模式 10 实现引导滤波/
        # 磨皮，并使用主模式 11 实现暗光增强。修改编码时须同步更新两套
        # FPGA 工程的 uart_cmd_parser.v、video_algo_manager.v 和算法索引文档。
        self.algo_config = [
            ("RAW PASS", "🌌 原图直出", (0, 0), None),
            ("COLOR SPACE", "🎨 色域空间转换", None, {"RGB 转换 YCbCr": (1, 1), "RGB 转换 HSV": (2, 0)}),
            ("SCALE ENGINE", "🔍 图像缩放", None, {"缩小 4 倍": (3, 0), "缩小 2 倍": (3, 1), "放大 2 倍": (4, 0), "放大 4 倍": (4, 1)}),
            ("ROTATION", "🔄 图像旋转", None, {"旋转 180°": (5, 0), "旋转 90°": (5, 1)}),
            ("HIST_EQ", "📊 直方图均衡化", (6, 0), None),
            ("MORPHOLOGY", "🦠 形态学操作", None, {"腐蚀 (Erosion)": (7, 0), "膨胀 (Dilation)": (7, 1)}),
            ("SOBEL", "📝 边缘检测", (10, 0), None),
            ("AFFINE", "📐 仿射变换", (5, 2), None),
            ("HDR TONE", "✨ HDR", (8, 0), None),
            ("BILATERAL", "🌫️ 双边滤波", (9, 0), None),
            ("GUIDED", "🌟 引导滤波", (10, 0), None),
            ("LOWLIGHT", "🌙 暗光处理", (11, 0), None),
            ("BEAUTY", "👸 磨皮美颜", (10, 1), None),
        ]

        self.init_ui()
        self.refresh_ports()

    def init_ui(self):
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.setStyleSheet("""
            QWidget { background: transparent; }

            QLabel#Title {
                background: transparent;
                color: rgba(255,255,255,245);
                font-size: 24px;
                font-weight: 700;
            }
            QLabel#Sub {
                background: transparent;
                color: rgba(255,255,255,135);
                font-size: 13px;
            }
            QLabel#Label {
                background: transparent;
                color: rgba(255,255,255,190);
                font-size: 14px;
                font-weight: 600;
            }
            QLabel#State {
                background: rgba(25, 39, 82, 42);
                color: rgba(255,255,255,135);
                border: 1px solid rgba(255,255,255,34);
                border-radius: 10px;
                padding: 7px 10px;
                font-size: 12px;
            }

            QComboBox {
                background: rgba(22, 34, 72, 48);
                color: white;
                border: 1px solid rgba(255,255,255,42);
                border-radius: 10px;
                padding: 8px 12px;
                font-size: 15px;
                font-weight: 600;
            }
            QComboBox:hover {
                background: rgba(105,130,255,22);
                border-color: rgba(180,205,255,76);
            }
            QComboBox::drop-down { border: none; width: 26px; }
            QComboBox QAbstractItemView {
                background-color: rgba(18,26,48,245);
                color: white;
                border: 1px solid rgba(255,255,255,40);
                selection-background-color: rgba(78,108,225,170);
            }

            QPushButton#Small, QPushButton#Connect, QPushButton#Back {
                background: rgba(22, 34, 72, 42);
                color: white;
                border: 1px solid rgba(255,255,255,42);
                border-radius: 10px;
                padding: 8px 14px;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton#Small:hover, QPushButton#Back:hover {
                background: rgba(110,135,255,22);
                border-color: rgba(180,205,255,82);
            }
            QPushButton#Connect:checked {
                background: rgba(85,120,255,44);
                border-color: rgba(165,190,255,102);
            }

            QPushButton#Algo {
                background: rgba(20, 32, 70, 48);
                color: rgba(255,255,255,236);
                border: 1px solid rgba(255,255,255,38);
                border-radius: 14px;
                padding: 22px;
                font-size: 18px;
                font-weight: 600;
                text-align: left;
            }
            QPushButton#Algo:hover {
                background: rgba(90,120,230,42);
                border-color: rgba(176,202,255,82);
                color: white;
            }
            QPushButton#Algo:pressed {
                background: rgba(78,108,225,54);
                border-color: rgba(160,188,255,100);
            }
            QPushButton#Algo[active="true"] {
                background: rgba(60, 92, 205, 34);
                border: 1px solid rgba(144, 182, 255, 122);
                color: white;
            }
            QLabel#State[status="connected"] {
                color: rgba(177, 235, 202, 235);
                border-color: rgba(105, 218, 151, 72);
                background: rgba(33, 111, 72, 32);
            }
            QLabel#State[status="sent"] {
                color: rgba(191, 211, 255, 240);
                border-color: rgba(136, 172, 255, 92);
                background: rgba(67, 99, 205, 40);
            }
        """)

        root = QVBoxLayout(self)
        root.setContentsMargins(18, 14, 18, 18)
        root.setSpacing(14)

        top = QHBoxLayout()
        text = QVBoxLayout()
        text.setSpacing(2)
        title = QLabel("FPGA VISION CONSOLE")
        title.setObjectName("Title")
        sub = QLabel("算法控制 · 串口指令")
        sub.setObjectName("Sub")
        text.addWidget(title)
        text.addWidget(sub)
        top.addLayout(text)
        top.addStretch()
        root.addLayout(top)

        connect_rule = TransparentRule(radius=14)
        cl = QHBoxLayout(connect_rule)
        cl.setContentsMargins(13, 10, 13, 10)
        cl.setSpacing(10)

        port_label = QLabel("串口端口")
        port_label.setObjectName("Label")
        self.cmb_port = QComboBox()
        self.cmb_port.setMinimumWidth(210)

        self.btn_refresh = QPushButton("更新串口")
        self.btn_refresh.setObjectName("Small")
        self.btn_refresh.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_refresh.clicked.connect(self.refresh_ports)

        self.btn_connect = QPushButton("连接")
        self.btn_connect.setObjectName("Connect")
        self.btn_connect.setCheckable(True)
        self.btn_connect.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_connect.clicked.connect(self.toggle_connection)

        self.lbl_state = QLabel("○ 未连接")
        self.lbl_state.setObjectName("State")
        self.lbl_state.setProperty("status", "disconnected")

        cl.addWidget(port_label)
        cl.addWidget(self.cmb_port)
        cl.addWidget(self.btn_refresh)
        cl.addWidget(self.btn_connect)
        cl.addWidget(self.lbl_state)
        cl.addStretch()
        root.addWidget(connect_rule)

        self.stack = QStackedWidget()
        self.stack.setStyleSheet("background: transparent; border: none;")
        root.addWidget(self.stack, stretch=1)

        self.page_main = QWidget()
        self.page_main.setProperty("pageDisplayName", "算法总览")
        self._video_return_page = self.page_main
        page_layout = QVBoxLayout(self.page_main)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(10)

        # 主页固定为首个页面；子页面通过 QWidget 引用关联，避免索引变化造成错配。
        self.stack.addWidget(self.page_main)

        algo_header = QHBoxLayout()
        algo_title = QLabel("选择算法")
        algo_title.setObjectName("Label")
        algo_hint = QLabel("Project 01 执行后自动进入图传监看")
        algo_hint.setObjectName("Sub")
        algo_header.addWidget(algo_title)
        algo_header.addStretch()
        algo_header.addWidget(algo_hint)
        page_layout.addLayout(algo_header)

        grid = QGridLayout()
        grid.setSpacing(12)
        grid.setContentsMargins(0, 0, 0, 0)

        for idx, (eng_title, zh_title, direct_mode_tuple, sub_menu) in enumerate(self.algo_config):
            row, col = idx // 4, idx % 4
            btn = AlgorithmButton(f"{eng_title}\n{zh_title}")
            btn.setObjectName("Algo")
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            is_project_1 = idx <= 9

            if direct_mode_tuple is not None:
                key = f"{eng_title}:DIRECT"
                recent_label = self._friendly_label(eng_title, zh_title)
                hud_label = self._hud_label(eng_title, recent_label)
                self._register_algorithm(
                    key, direct_mode_tuple[0], direct_mode_tuple[1], is_project_1,
                    recent_label, hud_label, self.page_main, btn, None
                )
                btn.clicked.connect(lambda checked, k=key: self.execute_algorithm(k))
            else:
                # 直接绑定子页面对象，新增或调整页面时无需维护脆弱的数字索引。
                page_widget = self.create_sub_page(
                    eng_title, zh_title, sub_menu, is_project_1, btn
                )
                btn.clicked.connect(
                    lambda checked, page=page_widget: self.stack.setCurrentWidget(page)
                )

            grid.addWidget(btn, row, col)

        page_layout.addLayout(grid, stretch=1)
        self.stack.setCurrentWidget(self.page_main)

    def create_sub_page(self, eng_title, zh_title, options, is_project_1, parent_module_button):
        page = QWidget()
        page.setProperty("pageDisplayName", zh_title)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        header = QHBoxLayout()
        back = QPushButton("← 返回全部算法")
        back.setObjectName("Back")
        back.setCursor(Qt.CursorShape.PointingHandCursor)
        back.clicked.connect(self.show_main_menu)

        title = QLabel(f"{eng_title}  ·  {zh_title}")
        title.setObjectName("Label")
        header.addWidget(back)
        header.addSpacing(8)
        header.addWidget(title)
        header.addStretch()
        layout.addLayout(header)

        grid = QGridLayout()
        grid.setSpacing(12)

        for idx, (opt_name, mode_tuple) in enumerate(options.items()):
            row, col = idx // 2, idx % 2
            btn = AlgorithmButton(opt_name)
            btn.setObjectName("Algo")
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)

            key = f"{eng_title}:{opt_name}"
            recent_label = self._friendly_label(eng_title, zh_title, opt_name)
            hud_label = self._hud_label(eng_title, recent_label, opt_name)
            self._register_algorithm(
                key, mode_tuple[0], mode_tuple[1], is_project_1,
                recent_label, hud_label, page, btn, parent_module_button
            )
            btn.clicked.connect(lambda checked, k=key: self.execute_algorithm(k))
            grid.addWidget(btn, row, col)

        layout.addLayout(grid, stretch=1)
        self.stack.addWidget(page)
        return page

    @staticmethod
    def _friendly_label(eng_title, zh_title, opt_name=None):
        if opt_name:
            return opt_name.replace("RGB 转换 ", "RGB → ")
        parts = zh_title.split(" ", 1)
        return parts[1] if len(parts) == 2 else zh_title

    @staticmethod
    def _hud_label(eng_title, recent_label, opt_name=None):
        if opt_name:
            if "YCbCr" in opt_name:
                return "YCbCr"
            if "HSV" in opt_name:
                return "HSV"
            if "Erosion" in opt_name or "腐蚀" in opt_name:
                return "Erosion"
            if "Dilation" in opt_name or "膨胀" in opt_name:
                return "Dilation"
            return recent_label.replace(" 倍", "×")
        mapping = {
            "RAW PASS": "RAW",
            "HIST_EQ": "HIST EQ",
            "SOBEL": "SOBEL",
            "AFFINE": "AFFINE",
            "HDR TONE": "HDR",
            "BILATERAL": "BILATERAL",
            "GUIDED": "GUIDED",
            "LOWLIGHT": "LOWLIGHT",
            "BEAUTY": "BEAUTY",
        }
        return mapping.get(eng_title, recent_label)

    def _register_algorithm(self, key, main_mode, sub_mode, is_project_1,
                            recent_label, hud_label, source_page, button, parent_button):
        self._algorithm_registry[key] = {
            "key": key,
            "main_mode": main_mode,
            "sub_mode": sub_mode,
            "is_project_1": is_project_1,
            "recent_label": recent_label,
            "hud_label": hud_label,
            "source_page": source_page,
            "button": button,
            "parent_button": parent_button,
        }

    def _set_active_algorithm(self, meta):
        for button in self._active_buttons:
            if isinstance(button, AlgorithmButton):
                button.set_active(False)
        self._active_buttons = []

        primary = meta.get("button")
        parent = meta.get("parent_button")
        for button in (primary, parent):
            if isinstance(button, AlgorithmButton) and button not in self._active_buttons:
                button.set_active(True)
                self._active_buttons.append(button)
        self._active_algorithm_key = meta["key"]

    def _set_serial_state(self, text, status="disconnected", idle=False):
        self.lbl_state.setText(text)
        self.lbl_state.setProperty("status", status)
        self.lbl_state.style().unpolish(self.lbl_state)
        self.lbl_state.style().polish(self.lbl_state)
        if idle:
            self._serial_idle_text = text
        self.serial_status_changed.emit(text)

    def _restore_serial_idle_state(self, token):
        if token != self._serial_flash_token:
            return
        if self.ser and self.ser.is_open:
            self._set_serial_state(self._serial_idle_text, "connected")
        else:
            self._set_serial_state("○ 未连接", "disconnected", idle=True)

    def _flash_command_state(self, main_mode, sub_mode):
        self._serial_flash_token += 1
        token = self._serial_flash_token
        self._set_serial_state(
            f"↗ 命令已发送 {main_mode:02d} {sub_mode:02d}",
            "sent"
        )
        QTimer.singleShot(1100, lambda t=token: self._restore_serial_idle_state(t))

    def execute_algorithm(self, key):
        meta = self._algorithm_registry.get(key)
        if meta is None:
            return
        self.send_command(meta)

    def show_main_menu(self):
        self.stack.setCurrentWidget(self.page_main)

    def remember_video_return_page(self):
        """记录当前算法页，供图传页“返回算法选择”使用。"""
        current = self.stack.currentWidget()
        self._video_return_page = current if current is not None else self.page_main

    def consume_prepared_video_return_page(self):
        """算法命令已经明确指定来源页时，阻止主窗口再次用当前页面覆盖它。"""
        prepared = self._video_return_page_prepared
        self._video_return_page_prepared = False
        return prepared

    def restore_video_return_page(self):
        """回到进入图传前的页面；页面失效时安全回退到算法总览。"""
        target = self._video_return_page
        if target is None or self.stack.indexOf(target) < 0:
            target = self.page_main
        self.stack.setCurrentWidget(target)
        return target

    def video_return_page_name(self):
        target = self._video_return_page
        if target is None or self.stack.indexOf(target) < 0:
            target = self.page_main
        return target.property("pageDisplayName") or "算法总览"

    def refresh_ports(self):
        self.cmb_port.clear()
        ports = serial.tools.list_ports.comports()
        for p in ports:
            self.cmb_port.addItem(p.device)

    def toggle_connection(self):
        if self.btn_connect.isChecked():
            port = self.cmb_port.currentText()
            if not port:
                self.btn_connect.setChecked(False)
                QMessageBox.warning(self, "SYSTEM ERROR", "未选择端口。")
                return
            try:
                self.ser = serial.Serial(port, 1000000, timeout=1)
                self.btn_connect.setText("断开连接")
                idle_text = f"● {port} · 1,000,000 baud"
                self._set_serial_state(idle_text, "connected", idle=True)
                self.toast_requested.emit(f"串口已连接 · {port}", "success")
            except Exception as e:
                self.btn_connect.setChecked(False)
                self._set_serial_state("○ 未连接", "disconnected", idle=True)
                QMessageBox.warning(self, "连接失败", str(e))
        else:
            if self.ser:
                self.ser.close()
            self.btn_connect.setText("连接")
            self._set_serial_state("○ 未连接", "disconnected", idle=True)
            self.toast_requested.emit("串口已断开", "info")

    def send_command(self, meta):
        if not self.ser or not self.ser.is_open:
            QMessageBox.warning(self, "拒绝发送", "串口未连接，请先连接硬件。")
            return

        main_mode = meta["main_mode"]
        sub_mode = meta["sub_mode"]
        packet = bytearray([0xAA, main_mode, sub_mode, 0x55])
        try:
            self.ser.write(packet)
            self.ser.flush()

            self._set_active_algorithm(meta)
            self._flash_command_state(main_mode, sub_mode)
            self.algorithm_used.emit(meta["key"], meta["recent_label"])
            self.active_algorithm_changed.emit(meta["hud_label"])
            self.toast_requested.emit(
                f"命令已发送 · {meta['recent_label']}",
                "success"
            )

            if meta["is_project_1"]:
                # 返回目标绑定算法所属页面，确保快捷入口不会丢失来源上下文。
                source_page = meta.get("source_page") or self.page_main
                self._video_return_page = source_page
                self._video_return_page_prepared = True
                QTimer.singleShot(150, self.request_ethernet_switch.emit)
        except Exception as e:
            QMessageBox.critical(self, "发送错误", str(e))


# ============================================================
# 8. 以太网图传页
# ============================================================
class EthernetVideoWidget(QWidget):
    """展示实时视频，并提供截图、录像和返回控制。"""
    request_back = pyqtSignal()
    toast_requested = pyqtSignal(str, str)

    def __init__(self):
        super().__init__()
        self.current_save_dir = os.path.join(os.path.expanduser("~"), "Desktop")
        if not os.path.exists(self.current_save_dir):
            self.current_save_dir = os.getcwd()

        self._presented_frames = 0
        self._last_presented_count = 0
        self._last_sample_time = time.monotonic()
        self._fps = 0.0
        self._active = False

        self.init_ui()

        self.processor = VideoProcessorThread(self.current_save_dir)
        self.processor.snapshot_saved.connect(self._on_snapshot_saved)
        self.processor.start()

        # 源流目标就是 30 FPS，显示也按 30 FPS 节奏刷新，不再用 60Hz 重复重绘。
        self.display_interval_ms = max(1, round(1000 / FPS))
        self.display_timer = QTimer(self)
        self.display_timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.display_timer.timeout.connect(self.present_latest_frame)

        self.status_timer = QTimer(self)
        self.status_timer.timeout.connect(self.update_status)

    def init_ui(self):
        self.setStyleSheet("""
            QWidget { background: transparent; }
            QLabel#Title {
                background: transparent;
                color: rgba(255,255,255,245);
                font-size: 24px;
                font-weight: 700;
            }
            QLabel#Sub {
                background: transparent;
                color: rgba(255,255,255,135);
                font-size: 13px;
            }
            QLabel#Label {
                background: transparent;
                color: rgba(255,255,255,205);
                font-size: 14px;
                font-weight: 600;
            }
            QLabel#Muted {
                background: transparent;
                color: rgba(255,255,255,130);
                font-size: 12px;
            }
            QLabel#Badge {
                background: rgba(22, 34, 72, 38);
                color: rgba(255,255,255,165);
                border: 1px solid rgba(255,255,255,34);
                border-radius: 10px;
                padding: 7px 10px;
                font-size: 12px;
            }
            QPushButton#Tool, QPushButton#Back, QPushButton#Record {
                background: rgba(22, 34, 72, 44);
                color: white;
                border: 1px solid rgba(255,255,255,42);
                border-radius: 10px;
                padding: 9px 13px;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton#Tool:hover, QPushButton#Back:hover, QPushButton#Record:hover {
                background: rgba(86,116,230,40);
                border-color: rgba(255,255,255,65);
            }
            QPushButton#Record[recording="true"] {
                background: rgba(255,69,58,42);
                border-color: rgba(255,120,110,90);
            }
        """)

        root = QVBoxLayout(self)
        # 图传页尽量把面积让给实时画面：缩小外围留白与纵向间距。
        root.setContentsMargins(10, 8, 10, 10)
        root.setSpacing(8)

        header = QHBoxLayout()
        self.btn_back_algorithm = QPushButton("← 返回：算法总览")
        self.btn_back_algorithm.setObjectName("Back")
        self.btn_back_algorithm.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_back_algorithm.clicked.connect(self.request_back.emit)

        text = QVBoxLayout()
        text.setSpacing(2)
        title = QLabel("实时图传监看")
        title.setObjectName("Title")
        sub = QLabel("实时接收与显示")
        sub.setObjectName("Sub")
        text.addWidget(title)
        text.addWidget(sub)

        header.addWidget(self.btn_back_algorithm)
        header.addSpacing(5)
        header.addLayout(text)
        header.addStretch()
        root.addLayout(header)

        badges = QHBoxLayout()
        badges.setSpacing(6)
        resolution_badge = QLabel(f"{IMG_W} × {IMG_H}")
        resolution_badge.setObjectName("Badge")
        badges.addWidget(resolution_badge)
        self.badge_fps = QLabel("0.0 FPS")
        self.badge_fps.setObjectName("Badge")
        self.badge_stream = QLabel("等待视频")
        self.badge_stream.setObjectName("Badge")
        badges.addWidget(self.badge_fps)
        badges.addWidget(self.badge_stream)
        badges.addStretch()
        root.addLayout(badges)

        content = QHBoxLayout()
        content.setSpacing(8)

        video_rule = TransparentRule(radius=16)
        vl = QVBoxLayout(video_rule)
        vl.setContentsMargins(4, 4, 4, 4)
        vl.setSpacing(0)
        self.video_surface = VideoRasterWidget()
        vl.addWidget(self.video_surface, stretch=1)

        tools = TransparentRule(radius=16)
        # 控制区收窄，把更多横向空间交给 1024×600 实时画面。
        tools.setFixedWidth(205)
        tl = QVBoxLayout(tools)
        tl.setContentsMargins(10, 10, 10, 10)
        tl.setSpacing(8)

        t = QLabel("控制")
        t.setObjectName("Label")
        tl.addWidget(t)

        self.lbl_path = QLabel(f"保存至：\n{self.current_save_dir}")
        self.lbl_path.setObjectName("Muted")
        self.lbl_path.setWordWrap(True)
        tl.addWidget(self.lbl_path)

        self.btn_dir = QPushButton("📁 更改目录")
        self.btn_dir.setObjectName("Tool")
        self.btn_dir.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_dir.clicked.connect(self.change_directory)

        self.btn_snapshot = QPushButton("📸 手动拍照")
        self.btn_snapshot.setObjectName("Tool")
        self.btn_snapshot.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_snapshot.clicked.connect(self.trigger_snapshot)

        self.btn_record = QPushButton("⏺️ 开始录像")
        self.btn_record.setObjectName("Record")
        self.btn_record.setProperty("recording", False)
        self.btn_record.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_record.clicked.connect(self.toggle_recording)

        self.lbl_status = QLabel("等待 UDP 图像流...")
        self.lbl_status.setObjectName("Muted")
        self.lbl_status.setWordWrap(True)

        tl.addWidget(self.btn_dir)
        tl.addWidget(self.btn_snapshot)
        tl.addWidget(self.btn_record)
        tl.addStretch()
        tl.addWidget(self.lbl_status)

        content.addWidget(video_rule, stretch=1)
        content.addWidget(tools)
        root.addLayout(content, stretch=1)

    def set_active(self, active):
        self._active = active
        if active:
            # 切算法后重新从新帧起点同步，避免旧算法残帧/半帧进入显示。
            stream_resync_event.set()
            self.processor.clear_latest_frame()
            self.video_surface.clear_frame()
            self._presented_frames = 0
            self._last_presented_count = 0
            self._last_sample_time = time.monotonic()
            self._fps = 0.0
            self.badge_fps.setText("0.0 FPS")
            self.badge_stream.setText("等待视频")
            self.display_timer.stop()
            self.status_timer.start(500)
            # 给接收线程一点时间完成重新同步，避免切换瞬间闪出上一算法的旧帧。
            QTimer.singleShot(90, self._start_display_after_resync)
        else:
            self.display_timer.stop()
            self.status_timer.stop()

    def _start_display_after_resync(self):
        if self._active:
            self.processor.clear_latest_frame()
            self.display_timer.start(self.display_interval_ms)

    def present_latest_frame(self):
        if not self._active:
            return

        img_bgr = self.processor.take_latest_frame()
        if img_bgr is None:
            return

        # RGB565 解码在后台线程完成，界面线程只负责更新已转换的图像。
        # Qt6 支持 BGR888，直接显示 BGR 帧，少一次 cvtColor 和整帧 copy。
        self.video_surface.set_bgr_frame(img_bgr)
        self._presented_frames += 1
        self.badge_stream.setText("在线接收中")
        self.lbl_status.setText("🟢 正在接收图像流")

    def update_status(self):
        if not self._active:
            return

        now = time.monotonic()
        dt = now - self._last_sample_time
        if dt > 0:
            self._fps = (self._presented_frames - self._last_presented_count) / dt
        self._last_presented_count = self._presented_frames
        self._last_sample_time = now
        self.badge_fps.setText(f"{self._fps:.1f} FPS")

        if self.processor.last_frame_time > 0 and now - self.processor.last_frame_time > 1.2:
            self.badge_stream.setText("等待视频")
            if not self.processor.is_recording:
                self.lbl_status.setText("等待 UDP 图像流...")

    def set_return_target_name(self, page_name):
        """更新图传页返回按钮文字，让用户明确知道会回到哪个算法页面。"""
        page_name = page_name or "算法总览"
        self.btn_back_algorithm.setText(f"← 返回：{page_name}")

    def set_algorithm_hud(self, hud_text):
        self.video_surface.set_hud_text(hud_text)

    def _on_snapshot_saved(self, filepath):
        self.lbl_status.setText("📸 截图已保存")
        self.toast_requested.emit(f"截图已保存 · {os.path.basename(filepath)}", "success")

    def change_directory(self):
        new_dir = QFileDialog.getExistingDirectory(self, "选择保存目录", self.current_save_dir)
        if new_dir:
            self.current_save_dir = new_dir
            self.processor.save_directory = new_dir
            self.lbl_path.setText(f"保存至：\n{new_dir}")
            self.toast_requested.emit("保存目录已更新", "info")

    def trigger_snapshot(self):
        self.processor.take_snapshot = True
        self.lbl_status.setText("📸 截图将在下一帧保存")

    def toggle_recording(self):
        if not self.processor.is_recording:
            self.processor.is_recording = True
            self.btn_record.setText("⏹️ 停止录像")
            self.btn_record.setProperty("recording", True)
            self.btn_record.style().unpolish(self.btn_record)
            self.btn_record.style().polish(self.btn_record)
            self.lbl_status.setText("⏺️ 正在录制视频...")
            self.toast_requested.emit("开始录像", "info")
        else:
            self.processor.is_recording = False
            self.btn_record.setText("⏺️ 开始录像")
            self.btn_record.setProperty("recording", False)
            self.btn_record.style().unpolish(self.btn_record)
            self.btn_record.style().polish(self.btn_record)
            self.lbl_status.setText("✅ 录像已保存")
            self.toast_requested.emit("录像已停止并保存", "success")

    def stop_processor(self):
        self.display_timer.stop()
        self.status_timer.stop()
        self.processor.stop()


# ============================================================
# 9. 主窗口与全局导航
# ============================================================
class MainDashboard(QMainWindow):
    """组合算法控制、视频监看、状态栏和窗口行为。"""
    def __init__(self):
        super().__init__()
        self.setWindowTitle("中科亿海微 - 综合视觉开发平台")
        self.setWindowIcon(QIcon(ICON_PATH))
        self.resize(1400, 820)
        self.setMinimumSize(1120, 680)

        # Windows 上不要调用 showMaximized()：
        # translucent + frameless 的原生最大化会让 DWM 把窗口重新合成为不透明表面。
        # 用手动铺满屏幕的“伪最大化”，透明合成始终保持不变。
        self._manual_maximized = False
        self._normal_geometry = None

        # 关键：顶层窗口仍为透明 layered window，不启用 Acrylic/Mica；蓝色薄膜由 Qt 自身绘制
        self.setWindowFlags(
            Qt.WindowType.Window |
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowSystemMenuHint |
            Qt.WindowType.WindowMinMaxButtonsHint |
            Qt.WindowType.NoDropShadowWindowHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAutoFillBackground(False)

        self.setStyleSheet("""
            QMainWindow { background: transparent; }
            QWidget {
                background: transparent;
                font-family: "SF Pro Display", "PingFang SC", "Segoe UI Variable", "Microsoft YaHei UI";
            }
            QLabel#Brand {
                color: rgba(255,255,255,242);
                font-size: 18px;
                font-weight: 700;
                background: transparent;
            }
            QLabel#SideSection {
                color: rgba(255,255,255,105);
                font-size: 11px;
                font-weight: 700;
                letter-spacing: 1px;
                background: transparent;
            }
            QLabel#SideText {
                color: rgba(255,255,255,155);
                font-size: 12px;
                background: transparent;
            }
        """)

        root = QWidget()
        root.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        root.setStyleSheet("background: transparent; border: none;")
        root.setAutoFillBackground(False)
        self.setCentralWidget(root)

        outer = QVBoxLayout(root)
        outer.setContentsMargins(8, 8, 8, 8)
        outer.setSpacing(0)

        # 全窗只覆盖一层轻微蓝黑薄膜：桌面依旧可见，但文字和控件有稳定对比度
        shell = QFrame()
        shell.setObjectName("PureShell")
        shell.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        shell.setStyleSheet("""
            QFrame#PureShell {
                background: rgba(15, 24, 54, 66);
                border: 1px solid rgba(180,202,255,54);
                border-radius: 18px;
            }
        """)
        outer.addWidget(shell)

        shell_l = QVBoxLayout(shell)
        shell_l.setContentsMargins(0, 0, 0, 0)
        shell_l.setSpacing(0)

        self.title_bar = TransparentTitleBar(self)
        shell_l.addWidget(self.title_bar)

        # 透明分隔线
        line = QFrame()
        line.setFixedHeight(1)
        line.setStyleSheet("background: rgba(180,205,255,40); border: none;")
        shell_l.addWidget(line)

        body = QWidget()
        body.setStyleSheet("background: transparent; border: none;")
        body_l = QHBoxLayout(body)
        body_l.setContentsMargins(12, 12, 12, 12)
        body_l.setSpacing(12)

        sidebar = QFrame()
        sidebar.setFixedWidth(235)
        sidebar.setObjectName("Sidebar")
        sidebar.setStyleSheet("""
            QFrame#Sidebar {
                background: rgba(13, 23, 52, 78);
                border: 1px solid rgba(170,198,255,38);
                border-right: 1px solid rgba(180,205,255,44);
                border-radius: 16px;
            }
        """)
        sl = QVBoxLayout(sidebar)
        sl.setContentsMargins(10, 8, 18, 8)
        sl.setSpacing(9)

        brand = QLabel("deep console")
        brand.setObjectName("Brand")
        sl.addWidget(brand)

        section = QLabel("工作区")
        section.setObjectName("SideSection")
        sl.addWidget(section)

        self.btn_algo = SideNavButton("⌘  算法控制台")
        self.btn_video = SideNavButton("◉  实时图传")
        self.btn_algo.setChecked(True)
        self.btn_algo.clicked.connect(lambda: self.switch_module(0))
        self.btn_video.clicked.connect(lambda: self.switch_module(1))
        sl.addWidget(self.btn_algo)
        sl.addWidget(self.btn_video)

        sl.addSpacing(10)
        recent_title = QLabel("最近使用")
        recent_title.setObjectName("SideSection")
        sl.addWidget(recent_title)

        self._recent_algorithms = []
        self._recent_buttons = []
        for i in range(5):
            btn = RecentAlgoButton()
            btn.hide()
            btn.clicked.connect(lambda checked=False, idx=i: self._run_recent_algorithm(idx))
            self._recent_buttons.append(btn)
            sl.addWidget(btn)

        self.lbl_recent_empty = QLabel("暂无最近使用")
        self.lbl_recent_empty.setObjectName("SideText")
        sl.addWidget(self.lbl_recent_empty)

        sl.addSpacing(10)
        state = QLabel("状态")
        state.setObjectName("SideSection")
        sl.addWidget(state)

        self.lbl_side_serial = QLabel("串口：未连接")
        self.lbl_side_serial.setObjectName("SideText")
        self.lbl_side_udp = QLabel(f"UDP：{UDP_PORT}")
        self.lbl_side_udp.setObjectName("SideText")
        self.lbl_side_page = QLabel("页面：算法总览")
        self.lbl_side_page.setObjectName("SideText")
        sl.addWidget(self.lbl_side_serial)
        sl.addWidget(self.lbl_side_udp)
        sl.addWidget(self.lbl_side_page)
        sl.addStretch()


        self.stack_area = AppleTransitionStackedWidget()
        self.stack_area.setStyleSheet("background: transparent; border: none;")

        self.vision_widget = VisionControllerWidget()
        self.ethernet_widget = EthernetVideoWidget()
        self.stack_area.addWidget(self.vision_widget)
        self.stack_area.addWidget(self.ethernet_widget)

        body_l.addWidget(sidebar)
        body_l.addWidget(self.stack_area, stretch=1)
        shell_l.addWidget(body, stretch=1)

        self.vision_widget.request_ethernet_switch.connect(lambda: self.switch_module(1))
        # 图传页自己的“返回算法选择”回到进入图传前的算法页；
        # 左侧“算法控制台”仍作为总入口，回算法总览。
        self.ethernet_widget.request_back.connect(self.return_from_video)
        self.ethernet_widget.set_active(False)

        # 状态 / Toast / 最近使用 / HUD 联动
        self.vision_widget.serial_status_changed.connect(self._on_serial_status_changed)
        self.vision_widget.algorithm_used.connect(self._on_algorithm_used)
        self.vision_widget.active_algorithm_changed.connect(self.ethernet_widget.set_algorithm_hud)

        self.toast = ToastOverlay(self)
        self.vision_widget.toast_requested.connect(self.toast.show_message)
        self.ethernet_widget.toast_requested.connect(self.toast.show_message)

        # 同步状态
        self.vision_widget.btn_connect.clicked.connect(self.sync_status)
        self.vision_widget.btn_refresh.clicked.connect(self.sync_status)

        # ------------------------------------------------------------
        # 响应式字体：普通窗口保持原字号，窗口放大后字体同步放大。
        # 只缩放 font-size，不改变透明度、算法布局和功能逻辑。
        # ------------------------------------------------------------
        self._font_scale = 1.0
        self._base_font = QFont(QApplication.instance().font())
        self._base_stylesheets = []
        self._capture_base_stylesheets()

        # resizeEvent 触发很频繁，使用短延时合并连续 resize，避免拖动窗口时反复重刷 QSS。
        self._font_scale_timer = QTimer(self)
        self._font_scale_timer.setSingleShot(True)
        self._font_scale_timer.setInterval(70)
        self._font_scale_timer.timeout.connect(self._apply_responsive_font_scale)
        QTimer.singleShot(0, self._apply_responsive_font_scale)

    def _on_serial_status_changed(self, text):
        self.lbl_side_serial.setText(f"串口：{text}")

    def _on_algorithm_used(self, key, label):
        self._recent_algorithms = [item for item in self._recent_algorithms if item[0] != key]
        self._recent_algorithms.insert(0, (key, label))
        self._recent_algorithms = self._recent_algorithms[:5]
        self._refresh_recent_algorithms()

    def _refresh_recent_algorithms(self):
        self.lbl_recent_empty.setVisible(len(self._recent_algorithms) == 0)
        for i, button in enumerate(self._recent_buttons):
            if i < len(self._recent_algorithms):
                key, label = self._recent_algorithms[i]
                button.algorithm_key = key
                button.setText(f"↗  {label}")
                button.show()
            else:
                button.algorithm_key = None
                button.hide()

    def _run_recent_algorithm(self, index):
        if index < 0 or index >= len(self._recent_buttons):
            return
        key = self._recent_buttons[index].algorithm_key
        if not key:
            return
        self.vision_widget.execute_algorithm(key)

    def _capture_base_stylesheets(self):
        """保存所有现有控件的原始 QSS，后续始终从原始字号计算，避免重复放大。"""
        self._base_stylesheets.clear()
        widgets = [self] + self.findChildren(QWidget)
        for widget in widgets:
            sheet = widget.styleSheet()
            if sheet:
                self._base_stylesheets.append((widget, sheet))

    @staticmethod
    def _scale_font_sizes_in_qss(sheet, scale):
        """只替换 QSS 中的 font-size: Npx，颜色/透明度/边框等完全不动。"""
        def repl(match):
            base = float(match.group(1))
            value = max(1, int(round(base * scale)))
            return f"font-size: {value}px"

        return re.sub(r"font-size\s*:\s*([0-9]+(?:\.[0-9]+)?)px", repl, sheet)

    def _calculate_font_scale(self):
        # 1400×820 是当前设计基准尺寸。
        # 小窗口不继续缩小字体；只有放大时才增大，保证你现在窗口模式下的字号不变。
        w = max(1, self.width())
        h = max(1, self.height())
        raw = min(w / 1400.0, h / 820.0)

        # 最大放大到 1.55 倍：4K/超宽屏也不会夸张到破坏布局。
        return max(1.0, min(raw, 1.55))

    def _apply_responsive_font_scale(self):
        scale = self._calculate_font_scale()
        if abs(scale - self._font_scale) < 0.015:
            return

        self._font_scale = scale

        # 先调整没有写死 QSS font-size 的控件。
        app = QApplication.instance()
        if app is not None:
            font = QFont(self._base_font)
            base_pt = self._base_font.pointSizeF()
            if base_pt <= 0:
                base_pt = 11.0
            font.setPointSizeF(base_pt * scale)
            app.setFont(font)

        # 再把所有显式 px 字号从“原始 QSS”按比例重算。
        for widget, base_sheet in self._base_stylesheets:
            try:
                widget.setStyleSheet(self._scale_font_sizes_in_qss(base_sheet, scale))
            except RuntimeError:
                # 控件若已被 deleteLater，忽略即可。
                pass

        # 大字体需要重新布局一次，避免 QLabel / Button 仍使用旧尺寸缓存。
        if self.centralWidget() is not None:
            self.centralWidget().updateGeometry()
        self.updateGeometry()
        self.update()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "_font_scale_timer"):
            self._font_scale_timer.start()
        if hasattr(self, "toast"):
            self.toast.reposition()

    def is_manual_maximized(self):
        return self._manual_maximized

    def _current_screen_available_geometry(self):
        # 优先取窗口当前所在屏幕，兼容多显示器。
        handle = self.windowHandle()
        screen = handle.screen() if handle is not None else None
        if screen is None:
            screen = QGuiApplication.screenAt(self.frameGeometry().center())
        if screen is None:
            screen = QGuiApplication.primaryScreen()
        return screen.availableGeometry() if screen is not None else self.geometry()

    def _apply_transparent_surface_flags(self):
        # 最大化/还原之后再次明确透明属性，避免 Windows/Qt 重建原生窗口后丢 Alpha。
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAutoFillBackground(False)
        if self.centralWidget() is not None:
            self.centralWidget().setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
            self.centralWidget().setAutoFillBackground(False)

    def toggle_maximize(self):
        # 不使用 showMaximized()/showNormal()。
        # 对透明 frameless 窗口，Windows 原生最大化路径可能产生整窗黑底。
        if self._manual_maximized:
            self._manual_maximized = False
            if self._normal_geometry is not None and self._normal_geometry.isValid():
                self.setGeometry(self._normal_geometry)
            self._apply_transparent_surface_flags()
            self.update()
            return

        self._normal_geometry = self.geometry()
        target = self._current_screen_available_geometry()
        self._manual_maximized = True

        # 保持 WindowNoState，只改变几何尺寸 = “伪最大化”。
        # 这样 DWM 仍把它当透明 layered window 合成。
        self.setWindowState(Qt.WindowState.WindowNoState)
        self.setGeometry(target)
        self._apply_transparent_surface_flags()
        self.update()

    def showEvent(self, event):
        super().showEvent(event)
        self._apply_transparent_surface_flags()

    def sync_status(self):
        self.lbl_side_serial.setText(f"串口：{self.vision_widget.lbl_state.text()}")

    def return_from_video(self):
        """图传页返回：恢复到触发图传的来源算法页。"""
        self.ethernet_widget.set_active(False)
        self.vision_widget.restore_video_return_page()
        page_name = self.vision_widget.video_return_page_name()
        self.lbl_side_page.setText(f"页面：{page_name}")
        self.btn_algo.setChecked(True)
        self.btn_video.setChecked(False)
        self.stack_area.setCurrentIndex(0)
        self.sync_status()

    def switch_module(self, index):
        if index == 0:
            # 左侧导航的“算法控制台”是总入口，因此主动点击它仍回算法总览。
            self.ethernet_widget.set_active(False)
            self.vision_widget.show_main_menu()
            self.lbl_side_page.setText("页面：算法总览")
        else:
            # 从哪个算法页面进入图传，就记录哪个页面。
            # 例如：色域空间转换 -> YCbCr -> 图传，返回时必须回“色域空间转换”。
            if self.stack_area.currentIndex() == 0:
                if not self.vision_widget.consume_prepared_video_return_page():
                    self.vision_widget.remember_video_return_page()
            return_name = self.vision_widget.video_return_page_name()
            self.ethernet_widget.set_return_target_name(return_name)
            self.lbl_side_page.setText("页面：实时图传")

        self.btn_algo.setChecked(index == 0)
        self.btn_video.setChecked(index == 1)

        # 实时视频不参与 QWidget.grab() 动画，避免透明窗口下的画面残影/黑块。
        self.stack_area.setCurrentIndex(index)
        if index == 1:
            self.ethernet_widget.set_active(True)

        self.sync_status()

    def closeEvent(self, event):
        self.ethernet_widget.stop_processor()
        if self.vision_widget.ser and self.vision_widget.ser.is_open:
            self.vision_widget.ser.close()
        event.accept()


if __name__ == "__main__":
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("zkymw.integrated.console.v3")
    except Exception:
        pass

    net_thread = threading.Thread(target=receive_network_stream, daemon=True)
    net_thread.start()

    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    global_font = app.font()
    global_font.setPointSize(11)
    app.setFont(global_font)

    window = MainDashboard()
    window.show()
    sys.exit(app.exec())
