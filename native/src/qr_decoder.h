// Godot-facing decoder: accepts camera frames on the main thread and decodes
// them on two background threads, so scanning never delays rendering.
#pragma once

#include "android_camera.h"
#include "qr_core.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>

namespace godot {

class QrDecoder : public RefCounted {
	GDCLASS(QrDecoder, RefCounted)

public:
	QrDecoder();
	~QrDecoder() override;

	// Offers a frame for decoding. Older frames that no worker has started on are
	// dropped, so decoding always works on the newest picture. The first byte of
	// each pixel must be luminance, or the data must be RGB(A).
	//
	// While the picture is not changing, frames are only compared with the previous
	// one, apart from an occasional decode as a safety net. Decoding resumes on the
	// first frame that differs. Returns false if the arguments do not describe the data.
	bool submit_frame(const PackedByteArray &p_data, int p_width, int p_height, int p_bytes_per_pixel);

	// True while the picture has changed recently and frames are being decoded.
	bool is_scene_active() const;

	// The native camera delivers frames by itself, so no submit_frame() calls are
	// needed while it runs. Only Android has one; elsewhere these report false.
	bool has_native_camera(bool p_front) const;
	bool start_native_camera(bool p_front, int p_max_pixels, int p_idle_fps, int p_active_fps);
	void stop_native_camera();
	bool is_native_camera_running() const;

	// Returns the newest confirmed code since the last call as
	// { text: String, corners: PackedVector2Array, frame_size: Vector2i, pass: String },
	// or an empty Dictionary if there is none.
	Dictionary poll_result();

	// Counters for diagnostics: frames_submitted, frames_decoded, last_fast_ms, last_rescue_ms.
	Dictionary get_stats() const;

protected:
	static void _bind_methods();

private:
	struct Frame {
		std::vector<uint8_t> luminance;
		int width = 0;
		int height = 0;
		uint64_t sequence = 0;
	};

	struct Result {
		qrcore::Hit hit;
		int width = 0;
		int height = 0;
		qrcore::Pass pass = qrcore::Pass::Standard;
	};

	// Returns whether the scene is active. Called from one thread at a time: the main
	// thread for submit_frame(), or the camera thread for the native camera.
	bool accept_frame(const uint8_t *p_data, int p_width, int p_height, int p_row_stride, int p_bytes_per_pixel);

	void fast_worker();
	void rescue_worker();
	std::shared_ptr<const Frame> wait_for_frame(uint64_t &r_last_sequence);
	void report(const qrcore::Hit &p_hit, const Frame &p_frame, qrcore::Pass p_pass);

	std::mutex mutex_;
	std::condition_variable frame_ready_;
	std::shared_ptr<const Frame> latest_frame_;
	uint64_t next_sequence_ = 1;
	bool stopping_ = false;

	std::optional<Result> pending_result_;
	std::string candidate_text_;
	uint64_t candidate_sequence_ = 0;

	qrcore::MotionDetector motion_detector_;
	std::chrono::steady_clock::time_point last_change_;
	std::chrono::steady_clock::time_point last_idle_decode_;
	std::chrono::steady_clock::time_point ignore_changes_until_;
	std::atomic<bool> scene_active_{true};

	std::atomic<uint64_t> frames_submitted_{0};
	std::atomic<uint64_t> frames_decoded_{0};
	std::atomic<float> last_fast_ms_{0.0f};
	std::atomic<float> last_rescue_ms_{0.0f};

	std::thread fast_thread_;
	std::thread rescue_thread_;

#ifdef __ANDROID__
	std::unique_ptr<qrcore::AndroidCamera> camera_;
#endif
};

} // namespace godot
