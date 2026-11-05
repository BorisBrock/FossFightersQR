#include "qr_core.h"

#include <ReadBarcode.h>

#include <algorithm>
#include <cstdlib>
#include <exception>

namespace qrcore {
namespace {

// Magnifying a full 1080p frame would mean decoding 4K. Limiting the source to
// this size keeps the pass affordable, and distant codes tend to be aimed at.
constexpr int kMaxMagnifiedSourceWidth = 1280;
constexpr int kMaxMagnifiedSourceHeight = 720;

const ZXing::ReaderOptions &reader_options() {
	static const ZXing::ReaderOptions options = [] {
		ZXing::ReaderOptions o;
		o.setFormats(ZXing::BarcodeFormat::QRCode);
		o.setTryHarder(true);
		o.setTryInvert(true);
		o.setTryDownscale(true);
		o.setTryRotate(false); // Finder pattern detection is rotation invariant.
		o.setBinarizer(ZXing::Binarizer::LocalAverage);
		o.setMaxNumberOfSymbols(1);
		o.setTextMode(ZXing::TextMode::Plain);
		return o;
	}();
	return options;
}

// Box blur in time independent of the radius, using an integral image.
void box_blur(const uint8_t *src, int w, int h, int stride, int radius, std::vector<uint32_t> &integral, std::vector<uint8_t> &dst) {
	const size_t row = size_t(w) + 1;
	integral.resize(row * (size_t(h) + 1));
	std::fill_n(integral.begin(), row, 0u);
	for (int y = 0; y < h; ++y) {
		const uint8_t *in = src + size_t(y) * stride;
		const uint32_t *above = integral.data() + size_t(y) * row;
		uint32_t *current = integral.data() + (size_t(y) + 1) * row;
		current[0] = 0;
		uint32_t sum = 0;
		for (int x = 0; x < w; ++x) {
			sum += in[x];
			current[x + 1] = above[x + 1] + sum;
		}
	}
	dst.resize(size_t(w) * h);
	for (int y = 0; y < h; ++y) {
		const int y0 = std::max(0, y - radius), y1 = std::min(h, y + radius + 1);
		const uint32_t *top = integral.data() + size_t(y0) * row;
		const uint32_t *bottom = integral.data() + size_t(y1) * row;
		uint8_t *out = dst.data() + size_t(y) * w;
		for (int x = 0; x < w; ++x) {
			const int x0 = std::max(0, x - radius), x1 = std::min(w, x + radius + 1);
			const uint32_t area = uint32_t(x1 - x0) * uint32_t(y1 - y0);
			out[x] = uint8_t((bottom[x1] - bottom[x0] - top[x1] + top[x0]) / area);
		}
	}
}

// Divides out the local mean. The window is narrow compared to the Standard
// pass's thresholding, so that a shadow edge crossing the code stays contained.
void flatten(const uint8_t *src, int w, int h, int stride, std::vector<uint32_t> &integral, std::vector<uint8_t> &blurred, std::vector<uint8_t> &dst) {
	box_blur(src, w, h, stride, std::max(8, std::min(w, h) / 60), integral, blurred);
	dst.resize(size_t(w) * h);
	for (int y = 0; y < h; ++y) {
		const uint8_t *in = src + size_t(y) * stride;
		const uint8_t *mean = blurred.data() + size_t(y) * w;
		uint8_t *out = dst.data() + size_t(y) * w;
		for (int x = 0; x < w; ++x) {
			out[x] = uint8_t(std::min(255, int(in[x]) * 128 / std::max<int>(mean[x], 1)));
		}
	}
}

void sharpen(const uint8_t *src, int w, int h, int stride, std::vector<uint32_t> &integral, std::vector<uint8_t> &blurred, std::vector<uint8_t> &dst) {
	constexpr int kRadius = 2, kAmount = 2;
	box_blur(src, w, h, stride, kRadius, integral, blurred);
	dst.resize(size_t(w) * h);
	for (int y = 0; y < h; ++y) {
		const uint8_t *in = src + size_t(y) * stride;
		const uint8_t *mean = blurred.data() + size_t(y) * w;
		uint8_t *out = dst.data() + size_t(y) * w;
		for (int x = 0; x < w; ++x) {
			out[x] = uint8_t(std::clamp(int(in[x]) + kAmount * (int(in[x]) - int(mean[x])), 0, 255));
		}
	}
}

void reduce(const uint8_t *src, int w, int h, int stride, std::vector<uint8_t> &dst) {
	const int out_w = w / 2, out_h = h / 2;
	dst.resize(size_t(out_w) * out_h);
	for (int y = 0; y < out_h; ++y) {
		const uint8_t *a = src + size_t(y) * 2 * stride;
		const uint8_t *b = a + stride;
		uint8_t *out = dst.data() + size_t(y) * out_w;
		for (int x = 0; x < out_w; ++x) {
			out[x] = uint8_t((a[2 * x] + a[2 * x + 1] + b[2 * x] + b[2 * x + 1] + 2) / 4);
		}
	}
}

// Bilinear 2x upscale of a source rectangle.
void magnify(const uint8_t *src, int crop_w, int crop_h, int stride, std::vector<uint8_t> &dst) {
	const int out_w = crop_w * 2;
	dst.resize(size_t(out_w) * crop_h * 2);
	for (int y = 0; y < crop_h * 2; ++y) {
		const uint8_t *r0 = src + size_t(y / 2) * stride;
		const uint8_t *r1 = ((y & 1) && y / 2 + 1 < crop_h) ? r0 + stride : r0;
		uint8_t *out = dst.data() + size_t(y) * out_w;
		for (int x = 0; x < crop_w; ++x) {
			const int next = std::min(x + 1, crop_w - 1);
			out[x * 2] = uint8_t((r0[x] + r1[x] + 1) / 2);
			out[x * 2 + 1] = uint8_t((r0[x] + r0[next] + r1[x] + r1[next] + 2) / 4);
		}
	}
}

} // namespace

bool MotionDetector::update(const uint8_t *data, int width, int height, int row_stride, int pixel_step) {
	constexpr int kColumns = 32, kRows = 18, kCells = kColumns * kRows;
	constexpr int kSampleStep = 4; // Every 4th pixel in both directions is plenty for averages.
	constexpr int kChangeThreshold = 6 * 16; // Brightness levels out of 255, in 1/16 levels.
	constexpr int kMinChangedCells = 3;

	cells_.assign(kCells, 0);
	samples_.assign(kCells, 0);
	for (int y = 0; y < height; y += kSampleStep) {
		const uint8_t *row = data + size_t(y) * row_stride;
		const int cell_row = y * kRows / height;
		for (int x = 0; x < width; x += kSampleStep) {
			const int cell = cell_row * kColumns + x * kColumns / width;
			cells_[cell] += row[size_t(x) * pixel_step];
			samples_[cell] += 1;
		}
	}
	int64_t total_difference = 0;
	const bool comparable = width == width_ && height == height_ && previous_.size() == size_t(kCells);
	for (int i = 0; i < kCells; ++i) {
		cells_[i] = samples_[i] > 0 ? cells_[i] * 16 / samples_[i] : 0;
		if (comparable) {
			total_difference += cells_[i] - previous_[i];
		}
	}

	int changed = 0;
	if (comparable) {
		const int exposure_shift = int(total_difference / kCells);
		for (int i = 0; i < kCells; ++i) {
			if (std::abs(cells_[i] - previous_[i] - exposure_shift) > kChangeThreshold) {
				++changed;
			}
		}
	}
	previous_.swap(cells_);
	width_ = width;
	height_ = height;
	return !comparable || changed >= kMinChangedCells;
}

bool Decoder::decode(const uint8_t *lum, int width, int height, int stride, Pass pass, Hit &out) {
	float scale = 1.0f, offset_x = 0.0f, offset_y = 0.0f;
	int view_w = width, view_h = height;
	const uint8_t *view_data = lum;
	int view_stride = stride;

	switch (pass) {
		case Pass::Standard:
			break;
		case Pass::Reduced:
			reduce(lum, width, height, stride, scratch_);
			view_w = width / 2;
			view_h = height / 2;
			scale = 2.0f;
			break;
		case Pass::Magnified: {
			const int crop_w = std::min(width, kMaxMagnifiedSourceWidth);
			const int crop_h = std::min(height, kMaxMagnifiedSourceHeight);
			const int crop_x = (width - crop_w) / 2, crop_y = (height - crop_h) / 2;
			magnify(lum + size_t(crop_y) * stride + crop_x, crop_w, crop_h, stride, scratch_);
			view_w = crop_w * 2;
			view_h = crop_h * 2;
			scale = 0.5f;
			offset_x = float(crop_x);
			offset_y = float(crop_y);
			break;
		}
		case Pass::Flattened:
			flatten(lum, width, height, stride, integral_, blurred_, scratch_);
			break;
		case Pass::Sharpened:
			sharpen(lum, width, height, stride, integral_, blurred_, scratch_);
			break;
	}
	if (pass != Pass::Standard) {
		view_data = scratch_.data();
		view_stride = view_w;
	}

	try {
		const ZXing::ImageView view(view_data, view_w, view_h, ZXing::ImageFormat::Lum, view_stride);
		const ZXing::Barcode barcode = ZXing::ReadBarcode(view, reader_options());
		if (!barcode.isValid()) {
			return false;
		}
		out.text = barcode.text();
		const ZXing::Position &position = barcode.position();
		for (int i = 0; i < 4; ++i) {
			out.corners[i * 2] = float(position[i].x) * scale + offset_x;
			out.corners[i * 2 + 1] = float(position[i].y) * scale + offset_y;
		}
		return true;
	} catch (const std::exception &) {
		return false; // Only invalid image dimensions throw; treat as no code.
	}
}

} // namespace qrcore
