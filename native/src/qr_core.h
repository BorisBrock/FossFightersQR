// Engine-independent QR decoding core: no Godot types, so the same code runs in
// the GDExtension and in the qr_bench reliability benchmark.
#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace qrcore {

// One decode attempt. Live video supplies many frames per second, so instead of
// spending a long time on one frame, successive attempts use passes that each
// cover a different kind of hard image. Which passes earn their cost was measured
// with tools/qr_bench.cpp; see docs/qr_scanning.md.
enum class Pass {
	Standard,  // Adaptive threshold on the frame as delivered.
	Reduced,   // Averaged down 2x, cheap: noise, heavy blur and very large codes.
	Magnified, // Centre of the frame upscaled 2x: small and distant codes.
	Flattened, // Local light levels divided out: hard shadows across the code.
	Sharpened, // Unsharp mask: out-of-focus codes.
};

struct Hit {
	std::string text;
	// Corners in source-frame pixels: x0, y0, x1, y1, ... clockwise from the
	// code's own top-left, so they also reveal its orientation.
	std::array<float, 8> corners{};
};

// Holds scratch buffers so that per-frame decoding does not allocate.
// Not thread safe: use one instance per thread.
class Decoder {
public:
	// Decodes a tightly or loosely packed 8-bit luminance image.
	bool decode(const uint8_t *lum, int width, int height, int stride, Pass pass, Hit &out);

private:
	std::vector<uint8_t> scratch_;
	std::vector<uint32_t> integral_;
	std::vector<uint8_t> blurred_;
};

// Tells whether a picture changed since the previous call, cheaply enough to run on
// every frame. Compares coarse cell brightness, which averages away sensor noise, and
// discounts overall brightness shifts from the camera's auto exposure. When in doubt
// it reports a change: a false alarm only costs a little battery.
class MotionDetector {
public:
	// pixel_step is the distance between pixels in bytes; the first byte of each
	// pixel is taken as its brightness.
	bool update(const uint8_t *data, int width, int height, int row_stride, int pixel_step);

private:
	std::vector<int32_t> cells_;
	std::vector<int32_t> previous_;
	std::vector<int32_t> samples_;
	int width_ = 0;
	int height_ = 0;
};

} // namespace qrcore
