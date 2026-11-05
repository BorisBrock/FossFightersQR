// Direct access to an Android camera through the NDK. Frames go straight from the
// camera to a callback on the camera's thread, without the copies, GPU uploads and
// readback of Godot's camera feed, and the frame rate can follow demand. Godot's feed
// offers neither, which matters for a device that scans for hours with no preview.
#pragma once

#ifdef __ANDROID__

#include <camera/NdkCameraDevice.h>
#include <camera/NdkCameraManager.h>
#include <media/NdkImageReader.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

namespace qrcore {

class AndroidCamera {
public:
	// Receives each frame's luminance plane and returns whether the scene is active,
	// which selects the frame rate. Runs on the camera's thread.
	using FrameCallback = std::function<bool(const uint8_t *luminance, int width, int height, int row_stride)>;

	struct Settings {
		bool front = true;
		int max_pixels = 1280 * 720;
		int idle_fps = 15;
		int active_fps = 30;
	};

	explicit AndroidCamera(FrameCallback callback);
	~AndroidCamera();

	static bool has_camera_facing(bool front);

	bool start(const Settings &settings);
	void stop();

	// False once the system took the camera away or it failed; start() can then retry.
	bool is_running() const { return running_.load(std::memory_order_relaxed); }

private:
	static void on_image(void *context, AImageReader *reader);
	static void on_disconnected(void *context, ACameraDevice *device);
	static void on_error(void *context, ACameraDevice *device, int error);
	static void on_session_closed(void *context, ACameraCaptureSession *session);
	static void on_session_event(void *context, ACameraCaptureSession *session) {}

	bool select_stream(ACameraMetadata *characteristics, const Settings &settings);
	void select_fps_ranges(ACameraMetadata *characteristics, const Settings &settings);
	void set_fps_range(bool active);
	void release();

	FrameCallback callback_;

	ACameraManager *manager_ = nullptr;
	ACameraDevice *device_ = nullptr;
	AImageReader *reader_ = nullptr;
	ANativeWindow *window_ = nullptr;
	ACaptureSessionOutput *output_ = nullptr;
	ACaptureSessionOutputContainer *outputs_ = nullptr;
	ACameraOutputTarget *target_ = nullptr;
	ACaptureRequest *request_ = nullptr;
	ACameraCaptureSession *session_ = nullptr;

	ACameraDevice_StateCallbacks device_callbacks_{};
	ACameraCaptureSession_stateCallbacks session_callbacks_{};
	AImageReader_ImageListener image_listener_{};

	int width_ = 0;
	int height_ = 0;
	int32_t idle_fps_range_[2] = { 0, 0 };
	int32_t active_fps_range_[2] = { 0, 0 };
	bool rate_is_active_ = false;

	std::atomic<bool> running_{ false };

	// Guards frame delivery against stop(), and the wait for the session to close.
	std::mutex frame_mutex_;
	bool accepting_frames_ = false;
	std::mutex close_mutex_;
	std::condition_variable session_closed_;
	bool session_open_ = false;
};

} // namespace qrcore

#endif // __ANDROID__
