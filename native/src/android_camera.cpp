#include "android_camera.h"

#ifdef __ANDROID__

#include <camera/NdkCameraCaptureSession.h>
#include <camera/NdkCameraMetadata.h>
#include <camera/NdkCaptureRequest.h>
#include <media/NdkImage.h>

#include <android/log.h>

#include <chrono>

namespace qrcore {
namespace {

constexpr const char *kLogTag = "QrCamera";

// Finds the first camera on the wanted side, which is that side's main camera.
std::string find_camera(ACameraManager *manager, bool front) {
	ACameraIdList *ids = nullptr;
	if (ACameraManager_getCameraIdList(manager, &ids) != ACAMERA_OK || ids == nullptr) {
		return {};
	}
	std::string found;
	const uint8_t wanted = front ? ACAMERA_LENS_FACING_FRONT : ACAMERA_LENS_FACING_BACK;
	for (int i = 0; i < ids->numCameras && found.empty(); ++i) {
		ACameraMetadata *characteristics = nullptr;
		if (ACameraManager_getCameraCharacteristics(manager, ids->cameraIds[i], &characteristics) != ACAMERA_OK) {
			continue;
		}
		ACameraMetadata_const_entry facing{};
		if (ACameraMetadata_getConstEntry(characteristics, ACAMERA_LENS_FACING, &facing) == ACAMERA_OK && facing.count > 0 && facing.data.u8[0] == wanted) {
			found = ids->cameraIds[i];
		}
		ACameraMetadata_free(characteristics);
	}
	ACameraManager_deleteCameraIdList(ids);
	return found;
}

} // namespace

AndroidCamera::AndroidCamera(FrameCallback callback) :
		callback_(std::move(callback)) {
	device_callbacks_.context = this;
	device_callbacks_.onDisconnected = on_disconnected;
	device_callbacks_.onError = on_error;
	session_callbacks_.context = this;
	session_callbacks_.onClosed = on_session_closed;
	session_callbacks_.onReady = on_session_event;
	session_callbacks_.onActive = on_session_event;
	image_listener_.context = this;
	image_listener_.onImageAvailable = on_image;
}

AndroidCamera::~AndroidCamera() {
	stop();
}

bool AndroidCamera::has_camera_facing(bool front) {
	ACameraManager *manager = ACameraManager_create();
	const bool found = !find_camera(manager, front).empty();
	ACameraManager_delete(manager);
	return found;
}

bool AndroidCamera::select_stream(ACameraMetadata *characteristics, const Settings &settings) {
	ACameraMetadata_const_entry streams{};
	if (ACameraMetadata_getConstEntry(characteristics, ACAMERA_SCALER_AVAILABLE_STREAM_CONFIGURATIONS, &streams) != ACAMERA_OK) {
		return false;
	}
	int best_pixels = 0;
	for (uint32_t i = 0; i + 3 < streams.count; i += 4) {
		const int32_t format = streams.data.i32[i], width = streams.data.i32[i + 1], height = streams.data.i32[i + 2];
		const bool is_input = streams.data.i32[i + 3] != 0;
		const int pixels = width * height;
		if (!is_input && format == AIMAGE_FORMAT_YUV_420_888 && pixels <= settings.max_pixels && pixels > best_pixels) {
			best_pixels = pixels;
			width_ = width;
			height_ = height;
		}
	}
	return best_pixels > 0;
}

void AndroidCamera::select_fps_ranges(ACameraMetadata *characteristics, const Settings &settings) {
	ACameraMetadata_const_entry ranges{};
	if (ACameraMetadata_getConstEntry(characteristics, ACAMERA_CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES, &ranges) != ACAMERA_OK) {
		return;
	}
	// Idle: the slowest supported rate at or above the wish. Active: the rate whose
	// minimum is highest, because that limits exposure time and thus motion blur.
	int32_t idle_max = 0, active_min = 0, active_max = 0;
	for (uint32_t i = 0; i + 1 < ranges.count; i += 2) {
		const int32_t low = ranges.data.i32[i], high = ranges.data.i32[i + 1];
		if (high >= settings.idle_fps && (idle_max == 0 || high < idle_max || (high == idle_max && low > idle_fps_range_[0]))) {
			idle_fps_range_[0] = low;
			idle_fps_range_[1] = high;
			idle_max = high;
		}
		if (high <= settings.active_fps && (high > active_max || (high == active_max && low > active_min))) {
			active_fps_range_[0] = low;
			active_fps_range_[1] = high;
			active_min = low;
			active_max = high;
		}
	}
}

void AndroidCamera::set_fps_range(bool active) {
	rate_is_active_ = active;
	const int32_t *range = active ? active_fps_range_ : idle_fps_range_;
	if (range[1] <= 0) {
		return;
	}
	ACaptureRequest_setEntry_i32(request_, ACAMERA_CONTROL_AE_TARGET_FPS_RANGE, 2, range);
	if (session_ != nullptr) {
		ACameraCaptureSession_setRepeatingRequest(session_, nullptr, 1, &request_, nullptr);
	}
}

bool AndroidCamera::start(const Settings &settings) {
	stop();

	manager_ = ACameraManager_create();
	const std::string id = find_camera(manager_, settings.front);
	ACameraMetadata *characteristics = nullptr;
	if (id.empty() || ACameraManager_getCameraCharacteristics(manager_, id.c_str(), &characteristics) != ACAMERA_OK) {
		release();
		return false;
	}
	const bool have_stream = select_stream(characteristics, settings);
	idle_fps_range_[0] = idle_fps_range_[1] = active_fps_range_[0] = active_fps_range_[1] = 0;
	if (have_stream) {
		select_fps_ranges(characteristics, settings);
	}
	ACameraMetadata_free(characteristics);
	if (!have_stream) {
		release();
		return false;
	}

	const bool ok = ACameraManager_openCamera(manager_, id.c_str(), &device_callbacks_, &device_) == ACAMERA_OK &&
			AImageReader_new(width_, height_, AIMAGE_FORMAT_YUV_420_888, 2, &reader_) == AMEDIA_OK &&
			AImageReader_setImageListener(reader_, &image_listener_) == AMEDIA_OK &&
			AImageReader_getWindow(reader_, &window_) == AMEDIA_OK &&
			ACaptureSessionOutputContainer_create(&outputs_) == ACAMERA_OK &&
			ACaptureSessionOutput_create(window_, &output_) == ACAMERA_OK &&
			ACaptureSessionOutputContainer_add(outputs_, output_) == ACAMERA_OK &&
			ACameraDevice_createCaptureRequest(device_, TEMPLATE_PREVIEW, &request_) == ACAMERA_OK &&
			ACameraOutputTarget_create(window_, &target_) == ACAMERA_OK &&
			ACaptureRequest_addTarget(request_, target_) == ACAMERA_OK;
	if (!ok) {
		__android_log_print(ANDROID_LOG_ERROR, kLogTag, "Could not set up camera %s", id.c_str());
		release();
		return false;
	}

	{
		std::lock_guard lock(frame_mutex_);
		accepting_frames_ = true;
	}
	{
		std::lock_guard lock(close_mutex_);
		session_open_ = true;
	}
	// Starts at the active rate, as the first frames count as a change anyway.
	set_fps_range(true);
	if (ACameraDevice_createCaptureSession(device_, outputs_, &session_callbacks_, &session_) != ACAMERA_OK) {
		{
			std::lock_guard lock(close_mutex_);
			session_open_ = false;
		}
		release();
		return false;
	}
	if (ACameraCaptureSession_setRepeatingRequest(session_, nullptr, 1, &request_, nullptr) != ACAMERA_OK) {
		release();
		return false;
	}
	running_.store(true, std::memory_order_relaxed);
	return true;
}

void AndroidCamera::stop() {
	running_.store(false, std::memory_order_relaxed);
	release();
}

void AndroidCamera::release() {
	{
		std::lock_guard lock(frame_mutex_);
		accepting_frames_ = false;
	}
	if (reader_ != nullptr) {
		AImageReader_setImageListener(reader_, nullptr);
	}
	if (session_ != nullptr) {
		ACameraCaptureSession_stopRepeating(session_);
		ACameraCaptureSession_close(session_);
		session_ = nullptr;
		// The device must outlive the session. The timeout covers a device that
		// already died, which may never report the close.
		std::unique_lock lock(close_mutex_);
		session_closed_.wait_for(lock, std::chrono::seconds(2), [this] { return !session_open_; });
		session_open_ = false;
	}
	if (device_ != nullptr) {
		ACameraDevice_close(device_);
		device_ = nullptr;
	}
	if (request_ != nullptr) {
		ACaptureRequest_free(request_);
		request_ = nullptr;
	}
	if (target_ != nullptr) {
		ACameraOutputTarget_free(target_);
		target_ = nullptr;
	}
	if (outputs_ != nullptr) {
		ACaptureSessionOutputContainer_free(outputs_);
		outputs_ = nullptr;
	}
	if (output_ != nullptr) {
		ACaptureSessionOutput_free(output_);
		output_ = nullptr;
	}
	if (reader_ != nullptr) {
		AImageReader_delete(reader_); // Also releases window_.
		reader_ = nullptr;
		window_ = nullptr;
	}
	if (manager_ != nullptr) {
		ACameraManager_delete(manager_);
		manager_ = nullptr;
	}
}

void AndroidCamera::on_image(void *context, AImageReader *reader) {
	auto *self = static_cast<AndroidCamera *>(context);
	std::lock_guard lock(self->frame_mutex_);

	AImage *image = nullptr;
	if (AImageReader_acquireLatestImage(reader, &image) != AMEDIA_OK || image == nullptr) {
		return;
	}
	uint8_t *luminance = nullptr;
	int length = 0;
	int32_t row_stride = 0;
	if (self->accepting_frames_ && AImage_getPlaneData(image, 0, &luminance, &length) == AMEDIA_OK &&
			AImage_getPlaneRowStride(image, 0, &row_stride) == AMEDIA_OK &&
			length >= row_stride * (self->height_ - 1) + self->width_) {
		const bool active = self->callback_(luminance, self->width_, self->height_, row_stride);
		if (active != self->rate_is_active_) {
			self->set_fps_range(active);
		}
	}
	AImage_delete(image);
}

void AndroidCamera::on_disconnected(void *context, ACameraDevice *) {
	static_cast<AndroidCamera *>(context)->running_.store(false, std::memory_order_relaxed);
}

void AndroidCamera::on_error(void *context, ACameraDevice *, int error) {
	__android_log_print(ANDROID_LOG_ERROR, kLogTag, "Camera error %d", error);
	static_cast<AndroidCamera *>(context)->running_.store(false, std::memory_order_relaxed);
}

void AndroidCamera::on_session_closed(void *context, ACameraCaptureSession *) {
	auto *self = static_cast<AndroidCamera *>(context);
	{
		std::lock_guard lock(self->close_mutex_);
		self->session_open_ = false;
	}
	self->session_closed_.notify_all();
}

} // namespace qrcore

#endif // __ANDROID__
