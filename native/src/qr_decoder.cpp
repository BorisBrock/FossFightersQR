#include "qr_decoder.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstring>
#include <iterator>

namespace godot {
namespace {

// A rescue read has to be repeated on another frame within this many frames.
constexpr uint64_t kConfirmationWindowFrames = 45;

// A hand holding a code never stays perfectly still, but keep decoding for a while
// anyway, so that a code held steady gets every chance to be read.
constexpr auto kActiveHold = std::chrono::seconds(3);
// Slowing the camera down changes its exposure for a moment. Taking that for a change in
// the scene would wake the camera again, over and over.
constexpr auto kExposureSettleTime = std::chrono::seconds(1);
// Catches whatever the change detection misses, such as a very slowly moving code.
constexpr auto kIdleDecodeInterval = std::chrono::seconds(1);

const char *pass_name(qrcore::Pass p_pass) {
	switch (p_pass) {
		case qrcore::Pass::Standard:
			return "standard";
		case qrcore::Pass::Reduced:
			return "reduced";
		case qrcore::Pass::Magnified:
			return "magnified";
		case qrcore::Pass::Flattened:
			return "flattened";
		case qrcore::Pass::Sharpened:
			return "sharpened";
	}
	return "";
}

float elapsed_ms(std::chrono::steady_clock::time_point p_start) {
	return std::chrono::duration<float, std::milli>(std::chrono::steady_clock::now() - p_start).count();
}

} // namespace

void QrDecoder::_bind_methods() {
	ClassDB::bind_method(D_METHOD("submit_frame", "data", "width", "height", "bytes_per_pixel"), &QrDecoder::submit_frame);
	ClassDB::bind_method(D_METHOD("is_scene_active"), &QrDecoder::is_scene_active);
	ClassDB::bind_method(D_METHOD("has_native_camera", "front"), &QrDecoder::has_native_camera);
	ClassDB::bind_method(D_METHOD("start_native_camera", "front", "max_pixels", "idle_fps", "active_fps"), &QrDecoder::start_native_camera);
	ClassDB::bind_method(D_METHOD("stop_native_camera"), &QrDecoder::stop_native_camera);
	ClassDB::bind_method(D_METHOD("is_native_camera_running"), &QrDecoder::is_native_camera_running);
	ClassDB::bind_method(D_METHOD("poll_result"), &QrDecoder::poll_result);
	ClassDB::bind_method(D_METHOD("get_stats"), &QrDecoder::get_stats);
}

QrDecoder::QrDecoder() {
	fast_thread_ = std::thread(&QrDecoder::fast_worker, this);
	rescue_thread_ = std::thread(&QrDecoder::rescue_worker, this);
}

QrDecoder::~QrDecoder() {
	stop_native_camera(); // Ends frame delivery before the workers go away.
	{
		std::lock_guard lock(mutex_);
		stopping_ = true;
	}
	frame_ready_.notify_all();
	fast_thread_.join();
	rescue_thread_.join();
}

bool QrDecoder::submit_frame(const PackedByteArray &p_data, int p_width, int p_height, int p_bytes_per_pixel) {
	if (p_width <= 0 || p_height <= 0 || p_bytes_per_pixel < 1 || p_bytes_per_pixel > 4) {
		return false;
	}
	const size_t pixels = size_t(p_width) * size_t(p_height);
	if (size_t(p_data.size()) < pixels * size_t(p_bytes_per_pixel)) {
		return false;
	}

	accept_frame(p_data.ptr(), p_width, p_height, p_width * p_bytes_per_pixel, p_bytes_per_pixel);
	return true;
}

bool QrDecoder::accept_frame(const uint8_t *p_data, int p_width, int p_height, int p_row_stride, int p_bytes_per_pixel) {
	frames_submitted_.fetch_add(1, std::memory_order_relaxed);
	const auto now = std::chrono::steady_clock::now();
	if (motion_detector_.update(p_data, p_width, p_height, p_row_stride, p_bytes_per_pixel) && now >= ignore_changes_until_) {
		last_change_ = now;
	}
	const bool active = now - last_change_ < kActiveHold;
	if (!active && scene_active_.load(std::memory_order_relaxed)) {
		ignore_changes_until_ = now + kExposureSettleTime;
	}
	scene_active_.store(active, std::memory_order_relaxed);
	if (!active) {
		if (now - last_idle_decode_ < kIdleDecodeInterval) {
			return false;
		}
		last_idle_decode_ = now;
	}

	const size_t pixels = size_t(p_width) * size_t(p_height);
	auto frame = std::make_shared<Frame>();
	frame->width = p_width;
	frame->height = p_height;
	frame->luminance.resize(pixels);
	uint8_t *target = frame->luminance.data();
	if (p_bytes_per_pixel == 1) {
		for (int y = 0; y < p_height; ++y) {
			std::memcpy(target + size_t(y) * p_width, p_data + size_t(y) * p_row_stride, size_t(p_width));
		}
	} else if (p_bytes_per_pixel == 2) {
		for (size_t i = 0; i < pixels; ++i) {
			target[i] = p_data[i * 2]; // L8A8 or Y8Cx8.
		}
	} else {
		const size_t step = size_t(p_bytes_per_pixel);
		for (size_t i = 0; i < pixels; ++i) {
			const uint8_t *rgb = p_data + i * step;
			target[i] = uint8_t((rgb[0] + 2 * rgb[1] + rgb[2]) / 4);
		}
	}

	{
		std::lock_guard lock(mutex_);
		frame->sequence = next_sequence_++;
		latest_frame_ = std::move(frame);
	}
	frame_ready_.notify_all();
	return active;
}

bool QrDecoder::has_native_camera(bool p_front) const {
#ifdef __ANDROID__
	return qrcore::AndroidCamera::has_camera_facing(p_front);
#else
	return false;
#endif
}

bool QrDecoder::start_native_camera(bool p_front, int p_max_pixels, int p_idle_fps, int p_active_fps) {
#ifdef __ANDROID__
	if (!camera_) {
		camera_ = std::make_unique<qrcore::AndroidCamera>([this](const uint8_t *p_luminance, int p_width, int p_height, int p_row_stride) {
			accept_frame(p_luminance, p_width, p_height, p_row_stride, 1);
			return scene_active_.load(std::memory_order_relaxed);
		});
	}
	return camera_->start({ p_front, p_max_pixels, p_idle_fps, p_active_fps });
#else
	return false;
#endif
}

void QrDecoder::stop_native_camera() {
#ifdef __ANDROID__
	if (camera_) {
		camera_->stop();
	}
#endif
}

bool QrDecoder::is_native_camera_running() const {
#ifdef __ANDROID__
	return camera_ && camera_->is_running();
#else
	return false;
#endif
}

std::shared_ptr<const QrDecoder::Frame> QrDecoder::wait_for_frame(uint64_t &r_last_sequence) {
	std::unique_lock lock(mutex_);
	frame_ready_.wait(lock, [&] {
		return stopping_ || (latest_frame_ && latest_frame_->sequence != r_last_sequence);
	});
	if (stopping_) {
		return nullptr;
	}
	r_last_sequence = latest_frame_->sequence;
	return latest_frame_;
}

void QrDecoder::report(const qrcore::Hit &p_hit, const Frame &p_frame, qrcore::Pass p_pass) {
	// The Flattened and Sharpened filters invent edges, and the benchmark caught
	// them occasionally decoding garbage. They only count once a second read on a
	// different frame agrees. The other passes have produced no false reads.
	const bool needs_confirmation = p_pass == qrcore::Pass::Flattened || p_pass == qrcore::Pass::Sharpened;

	std::lock_guard lock(mutex_);
	const bool confirmed = p_hit.text == candidate_text_ && p_frame.sequence != candidate_sequence_ &&
			p_frame.sequence - candidate_sequence_ <= kConfirmationWindowFrames;
	if (needs_confirmation && !confirmed) {
		candidate_text_ = p_hit.text;
		candidate_sequence_ = p_frame.sequence;
		return;
	}
	candidate_text_ = p_hit.text;
	candidate_sequence_ = p_frame.sequence;
	pending_result_ = Result{ p_hit, p_frame.width, p_frame.height, p_pass };
}

void QrDecoder::fast_worker() {
	// Sees (nearly) every frame with the cheap passes that read ordinary codes.
	qrcore::Decoder decoder;
	uint64_t last_sequence = 0;
	while (const std::shared_ptr<const Frame> frame = wait_for_frame(last_sequence)) {
		const auto start = std::chrono::steady_clock::now();
		qrcore::Hit hit;
		for (const qrcore::Pass pass : { qrcore::Pass::Standard, qrcore::Pass::Reduced }) {
			if (decoder.decode(frame->luminance.data(), frame->width, frame->height, frame->width, pass, hit)) {
				report(hit, *frame, pass);
				break;
			}
		}
		last_fast_ms_.store(elapsed_ms(start), std::memory_order_relaxed);
		frames_decoded_.fetch_add(1, std::memory_order_relaxed);
	}
}

void QrDecoder::rescue_worker() {
	// Works through the slower passes for hard images on whichever frame is newest.
	static constexpr qrcore::Pass kCycle[] = { qrcore::Pass::Magnified, qrcore::Pass::Flattened, qrcore::Pass::Sharpened };
	qrcore::Decoder decoder;
	uint64_t last_sequence = 0;
	size_t next = 0;
	while (const std::shared_ptr<const Frame> frame = wait_for_frame(last_sequence)) {
		const qrcore::Pass pass = kCycle[next];
		next = (next + 1) % std::size(kCycle);
		const auto start = std::chrono::steady_clock::now();
		qrcore::Hit hit;
		if (decoder.decode(frame->luminance.data(), frame->width, frame->height, frame->width, pass, hit)) {
			report(hit, *frame, pass);
		}
		last_rescue_ms_.store(elapsed_ms(start), std::memory_order_relaxed);
	}
}

bool QrDecoder::is_scene_active() const {
	return scene_active_.load(std::memory_order_relaxed);
}

Dictionary QrDecoder::poll_result() {
	std::optional<Result> result;
	{
		std::lock_guard lock(mutex_);
		result.swap(pending_result_);
	}
	Dictionary out;
	if (!result) {
		return out;
	}
	PackedVector2Array corners;
	corners.resize(4);
	for (int i = 0; i < 4; ++i) {
		corners[i] = Vector2(result->hit.corners[i * 2], result->hit.corners[i * 2 + 1]);
	}
	out["text"] = String::utf8(result->hit.text.c_str(), int64_t(result->hit.text.size()));
	out["corners"] = corners;
	out["frame_size"] = Vector2i(result->width, result->height);
	out["pass"] = String(pass_name(result->pass));
	return out;
}

Dictionary QrDecoder::get_stats() const {
	Dictionary stats;
	stats["frames_submitted"] = int64_t(frames_submitted_.load(std::memory_order_relaxed));
	stats["scene_active"] = scene_active_.load(std::memory_order_relaxed);
	stats["frames_decoded"] = int64_t(frames_decoded_.load(std::memory_order_relaxed));
	stats["last_fast_ms"] = last_fast_ms_.load(std::memory_order_relaxed);
	stats["last_rescue_ms"] = last_rescue_ms_.load(std::memory_order_relaxed);
	return stats;
}

} // namespace godot
