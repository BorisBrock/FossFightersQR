"""QR code reading with OpenCV. The WeChat detector (opencv-contrib) finds small, blurry codes far better than
the plain detector, so it is used when available."""

import threading

import cv2

_lock = threading.Lock()
_wechat = cv2.wechat_qrcode_WeChatQRCode() if hasattr(cv2, "wechat_qrcode_WeChatQRCode") else None
_plain = cv2.QRCodeDetector()


def read_qr(image):
    """Text of the first QR code in the image, or "" if there is none."""
    with _lock:
        if _wechat is not None:
            texts, _ = _wechat.detectAndDecode(image)
            return texts[0] if texts else ""
        return _plain.detectAndDecode(image)[0]
