// Reliability benchmark for qr_core. Renders QR codes into synthetic camera
// frames under controlled conditions and reports the read rate per decode pass.
//
//   qr_bench [frames_per_condition] [width] [height]
//   qr_bench --false-positives [frames] [width] [height] [seed]
//   qr_bench --motion [frames] [width] [height]                  checks MotionDetector
//   qr_bench --render <text> <out.pgm> <seed> [width] [height]   writes one tilted sample frame
//
// A frame only counts as read if the decoded text equals the encoded text, so
// misreads count against the score and are also reported separately.
#include "../src/qr_core.h"

#include <BitMatrix.h>
#include <MultiFormatWriter.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <functional>
#include <random>
#include <string>
#include <vector>

namespace {

using Rng = std::mt19937;

float uniform(Rng &rng, float a, float b) {
	return std::uniform_real_distribution<float>(a, b)(rng);
}

struct Condition {
	const char *name;
	float module_px_min = 5, module_px_max = 9; // Apparent module size.
	float fill = 0;                             // If set: code side as fraction of frame height.
	float max_tilt_deg = 0;                     // Out-of-plane rotation.
	bool background_clutter = true;
	float blur_sigma = 0.6f;
	float motion_blur_px = 0;
	float paper = 0.85f, ink = 0.08f; // Reflectance of light and dark modules.
	float light = 1.0f;               // Overall brightness.
	float gradient = 0;               // Light falloff across the frame, 0..1.
	float glare = 0;                  // Strength of a soft bright hotspot.
	float shadow = 0;                 // Depth of a hard-edged shadow across the code.
	float noise_sigma = 2;
	bool inverted = false;
	bool centered = false; // Keep the code in the middle of the frame.
	bool no_code = false;  // Clutter only, for measuring false positives.
};

struct Point { float x, y; };

// 3x3 projective transform from code space to image space.
struct Homography {
	float m[9];
	Point map(float x, float y) const {
		const float w = m[6] * x + m[7] * y + m[8];
		return {(m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w};
	}
	Homography inverse() const {
		const float *a = m;
		const float c00 = a[4] * a[8] - a[5] * a[7], c01 = a[5] * a[6] - a[3] * a[8], c02 = a[3] * a[7] - a[4] * a[6];
		const float det = a[0] * c00 + a[1] * c01 + a[2] * c02;
		return {{c00 / det, (a[2] * a[7] - a[1] * a[8]) / det, (a[1] * a[5] - a[2] * a[4]) / det,
				c01 / det, (a[0] * a[8] - a[2] * a[6]) / det, (a[2] * a[3] - a[0] * a[5]) / det,
				c02 / det, (a[1] * a[6] - a[0] * a[7]) / det, (a[0] * a[4] - a[1] * a[3]) / det}};
	}
};

// Places a unit-square code by rotating it in 3D and projecting through a pinhole.
Homography place_code(float side_px, float roll, float tilt_a, float tilt_b, float cx, float cy) {
	const float focal = 1000.0f;
	const float ca = std::cos(tilt_a), sa = std::sin(tilt_a), cb = std::cos(tilt_b), sb = std::sin(tilt_b);
	const float cr = std::cos(roll), sr = std::sin(roll);
	// R = Rx(a) * Ry(b) * Rz(roll), columns r0 and r1 span the code plane.
	const float r0[3] = {cb * cr, ca * sr + sa * sb * cr, sa * sr - ca * sb * cr};
	const float r1[3] = {-cb * sr, ca * cr - sa * sb * sr, sa * cr + ca * sb * sr};
	const float s = side_px / focal;
	return {{focal * s * r0[0] + cx * s * r0[2], focal * s * r1[0] + cx * s * r1[2], cx - 0.5f * s * (focal * (r0[0] + r1[0]) + cx * (r0[2] + r1[2])),
			focal * s * r0[1] + cy * s * r0[2], focal * s * r1[1] + cy * s * r1[2], cy - 0.5f * s * (focal * (r0[1] + r1[1]) + cy * (r0[2] + r1[2])),
			s * r0[2], s * r1[2], 1.0f - 0.5f * s * (r0[2] + r1[2])}};
}

void box_blur_h(std::vector<float> &img, std::vector<float> &tmp, int w, int h, int r) {
	if (r <= 0) return;
	tmp.resize(img.size());
	for (int y = 0; y < h; ++y) {
		float sum = 0;
		const float *src = img.data() + size_t(y) * w;
		float *dst = tmp.data() + size_t(y) * w;
		for (int x = -r; x <= r; ++x) sum += src[std::clamp(x, 0, w - 1)];
		for (int x = 0; x < w; ++x) {
			dst[x] = sum / float(2 * r + 1);
			sum += src[std::min(x + r + 1, w - 1)] - src[std::max(x - r, 0)];
		}
	}
	img.swap(tmp);
}

void box_blur_v(std::vector<float> &img, std::vector<float> &tmp, int w, int h, int r) {
	if (r <= 0) return;
	tmp.resize(img.size());
	for (int x = 0; x < w; ++x) {
		float sum = 0;
		for (int y = -r; y <= r; ++y) sum += img[size_t(std::clamp(y, 0, h - 1)) * w + x];
		for (int y = 0; y < h; ++y) {
			tmp[size_t(y) * w + x] = sum / float(2 * r + 1);
			sum += img[size_t(std::min(y + r + 1, h - 1)) * w + x] - img[size_t(std::max(y - r, 0)) * w + x];
		}
	}
	img.swap(tmp);
}

// True separable Gaussian. Box-pass approximations cannot represent small sigmas.
void gaussian(std::vector<float> &img, std::vector<float> &tmp, int w, int h, float sigma) {
	if (sigma <= 0.05f) return;
	const int r = std::max(1, int(std::ceil(sigma * 3.0f)));
	std::vector<float> kernel(size_t(2 * r + 1));
	float total = 0;
	for (int i = -r; i <= r; ++i) total += kernel[size_t(i + r)] = std::exp(-float(i * i) / (2 * sigma * sigma));
	for (float &k : kernel) k /= total;
	tmp.resize(img.size());
	for (int y = 0; y < h; ++y) {
		const float *src = img.data() + size_t(y) * w;
		float *dst = tmp.data() + size_t(y) * w;
		for (int x = 0; x < w; ++x) {
			float sum = 0;
			for (int i = -r; i <= r; ++i) sum += src[std::clamp(x + i, 0, w - 1)] * kernel[size_t(i + r)];
			dst[x] = sum;
		}
	}
	for (int y = 0; y < h; ++y) {
		float *dst = img.data() + size_t(y) * w;
		for (int x = 0; x < w; ++x) dst[x] = 0;
		for (int i = -r; i <= r; ++i) {
			const float *src = tmp.data() + size_t(std::clamp(y + i, 0, h - 1)) * w;
			const float k = kernel[size_t(i + r)];
			for (int x = 0; x < w; ++x) dst[x] += src[x] * k;
		}
	}
}

struct Frame {
	std::vector<uint8_t> pixels;
	std::string text;
};

class Renderer {
public:
	Renderer(int width, int height) : w_(width), h_(height), linear_(size_t(width) * height) {}

	void render(const Condition &c, const ZXing::BitMatrix &code, Rng &rng, std::vector<uint8_t> &out) {
		const int quiet = 4;
		const int modules = code.width();
		const int total = modules + 2 * quiet;
		const float module_px = uniform(rng, c.module_px_min, c.module_px_max);
		const float side = c.fill > 0 ? c.fill * float(h_) : module_px * float(total);

		const float deg = 3.14159265f / 180.0f;
		const float direction = uniform(rng, 0, 6.2831853f);
		const float tilt = c.max_tilt_deg > 0 ? uniform(rng, c.max_tilt_deg * 0.7f, c.max_tilt_deg) * deg : 0;
		const float roll = uniform(rng, 0, 6.2831853f);
		// Half the diagonal keeps a code of any roll fully in frame whenever it fits.
		const float margin = std::min(side * 0.75f, std::min(w_, h_) * 0.5f);
		const float cx = c.centered ? w_ * 0.5f + uniform(rng, -0.1f, 0.1f) * w_ : uniform(rng, margin, w_ - margin);
		const float cy = c.centered ? h_ * 0.5f + uniform(rng, -0.1f, 0.1f) * h_ : uniform(rng, margin, h_ - margin);
		const Homography forward = place_code(side, roll, tilt * std::cos(direction), tilt * std::sin(direction), cx, cy);
		const Homography inverse = forward.inverse();

		// Random-rectangle clutter, so the decoder sees edges other than the code.
		const float bg_a = uniform(rng, 0.2f, 0.7f);
		std::fill(linear_.begin(), linear_.end(), bg_a);
		if (c.background_clutter) {
			for (int i = 0; i < 60; ++i) {
				const int rw = int(uniform(rng, 4, w_ * 0.2f)), rh = int(uniform(rng, 4, h_ * 0.2f));
				const int rx = int(uniform(rng, 0, float(w_))), ry = int(uniform(rng, 0, float(h_)));
				const float v = uniform(rng, 0.03f, 0.95f);
				for (int y = ry; y < std::min(h_, ry + rh); ++y)
					std::fill_n(linear_.begin() + size_t(y) * w_ + rx, std::max(0, std::min(w_ - rx, rw)), v);
			}
		}

		const float paper = c.inverted ? c.ink : c.paper;
		const float ink = c.inverted ? c.paper : c.ink;
		// 3x3 supersampling of the code into the frame.
		for (int y = 0; y < h_ && !c.no_code; ++y) {
			for (int x = 0; x < w_; ++x) {
				float sum = 0;
				int inside = 0;
				for (int sy = 0; sy < 3; ++sy) {
					for (int sx = 0; sx < 3; ++sx) {
						const Point p = inverse.map(float(x) + (float(sx) + 0.5f) / 3.0f, float(y) + (float(sy) + 0.5f) / 3.0f);
						if (p.x < 0 || p.y < 0 || p.x >= 1 || p.y >= 1) continue;
						++inside;
						const int mx = int(p.x * float(total)) - quiet, my = int(p.y * float(total)) - quiet;
						const bool dark = mx >= 0 && my >= 0 && mx < modules && my < modules && code.get(mx, my);
						sum += dark ? ink : paper;
					}
				}
				if (inside) {
					float &px = linear_[size_t(y) * w_ + x];
					px = (px * float(9 - inside) + sum) / 9.0f;
				}
			}
		}

		// Lighting acts on scene reflectance, before lens blur.
		const float gx = uniform(rng, -1, 1), gy = uniform(rng, -1, 1);
		const float norm = std::sqrt(gx * gx + gy * gy) + 1e-3f;
		const Point glare_at = forward.map(uniform(rng, 0.2f, 0.8f), uniform(rng, 0.2f, 0.8f));
		const float glare_radius = side * uniform(rng, 0.2f, 0.4f);
		const Point shadow_at = forward.map(uniform(rng, 0.3f, 0.7f), uniform(rng, 0.3f, 0.7f));
		const float shadow_angle = uniform(rng, 0, 6.2831853f);
		const float sx = std::cos(shadow_angle), sy = std::sin(shadow_angle);
		for (int y = 0; y < h_; ++y) {
			for (int x = 0; x < w_; ++x) {
				float value = linear_[size_t(y) * w_ + x];
				float light = c.light;
				if (c.gradient > 0) {
					const float t = ((float(x) / w_ - 0.5f) * gx + (float(y) / h_ - 0.5f) * gy) / norm;
					light *= 1.0f - c.gradient * (t + 0.5f);
				}
				if (c.shadow > 0 && (float(x) - shadow_at.x) * sx + (float(y) - shadow_at.y) * sy > 0) {
					light *= 1.0f - c.shadow;
				}
				value *= light;
				if (c.glare > 0) {
					const float dx = (float(x) - glare_at.x) / glare_radius, dy = (float(y) - glare_at.y) / glare_radius;
					value += c.glare * std::exp(-(dx * dx + dy * dy));
				}
				linear_[size_t(y) * w_ + x] = value;
			}
		}

		gaussian(linear_, tmp_, w_, h_, c.blur_sigma);
		if (c.motion_blur_px > 0) {
			// Linear motion, approximated by the dominant axis.
			const int r = std::max(1, int(c.motion_blur_px / 2));
			if (uniform(rng, 0, 1) < 0.5f) box_blur_h(linear_, tmp_, w_, h_, r);
			else box_blur_v(linear_, tmp_, w_, h_, r);
		}

		out.resize(linear_.size());
		std::normal_distribution<float> noise(0.0f, c.noise_sigma);
		for (size_t i = 0; i < linear_.size(); ++i) {
			const float gamma = std::pow(std::clamp(linear_[i], 0.0f, 1.0f), 1.0f / 2.2f);
			out[i] = uint8_t(std::clamp(gamma * 255.0f + noise(rng), 0.0f, 255.0f));
		}
	}

private:
	int w_, h_;
	std::vector<float> linear_, tmp_;
};

ZXing::BitMatrix make_code(const std::string &text) {
	// Margin 0 and size 1: one matrix cell per module, the renderer adds the quiet zone.
	ZXing::MultiFormatWriter writer(ZXing::BarcodeFormat::QRCode);
	writer.setMargin(0);
	writer.setEncoding(ZXing::CharacterSet::UTF8);
	return writer.encode(text, 1, 1);
}

struct Tally {
	int reads = 0, wrong = 0;
	double ms = 0;
};

} // namespace

// Scanning never stops, so hour after hour it mostly sees frames without a code.
// Any read here would be a pling for a code that does not exist.
int count_false_positives(int frames, int width, int height, unsigned seed) {
	const std::vector<std::pair<const char *, qrcore::Pass>> passes = {
		{"standard", qrcore::Pass::Standard}, {"reduced", qrcore::Pass::Reduced}, {"magnify", qrcore::Pass::Magnified},
		{"flatten", qrcore::Pass::Flattened}, {"sharpen", qrcore::Pass::Sharpened},
	};
	std::vector<int> hits(passes.size());
	Condition condition;
	condition.no_code = true;
	Renderer renderer(width, height);
	qrcore::Decoder decoder;
	const ZXing::BitMatrix unused = make_code("x");
	std::vector<uint8_t> pixels;
	Rng rng(seed);
	for (int f = 0; f < frames; ++f) {
		condition.noise_sigma = uniform(rng, 2, 10);
		condition.blur_sigma = uniform(rng, 0.3f, 3);
		condition.light = uniform(rng, 0.05f, 1);
		renderer.render(condition, unused, rng, pixels);
		for (size_t p = 0; p < passes.size(); ++p) {
			qrcore::Hit hit;
			if (decoder.decode(pixels.data(), width, height, width, passes[p].second, hit)) {
				++hits[p];
				std::printf("frame %d, %s: '%s'\n", f, passes[p].first, hit.text.c_str());
			}
		}
	}
	std::printf("False positives in %d code-free frames:", frames);
	for (size_t p = 0; p < passes.size(); ++p) std::printf(" %s=%d", passes[p].first, hits[p]);
	std::printf("\n");
	return 0;
}

// A detector that fires on noise wastes battery; one that misses a code wastes the
// player's time. Static scenes must stay quiet, and small movements must register.
int check_motion_detector(int frames, int width, int height) {
	struct Case { const char *name; float noise; float exposure_jitter; };
	const std::vector<Case> static_cases = {
		{"clean", 1, 0}, {"noisy", 5, 0}, {"very noisy", 10, 0}, {"exposure +-1%", 3, 0.01f}, {"exposure +-3%", 3, 0.03f},
	};
	const ZXing::BitMatrix code = make_code("MOTION");
	Rng rng(5);
	Condition condition;
	condition.centered = true;
	std::vector<uint8_t> base;
	Renderer renderer(width, height);
	renderer.render(condition, code, rng, base);
	for (const Case &c : static_cases) {
		qrcore::MotionDetector detector;
		std::normal_distribution<float> noise(0.0f, c.noise);
		std::vector<uint8_t> frame(base.size());
		int fired = 0;
		for (int f = 0; f < frames; ++f) {
			const float gain = 1.0f + uniform(rng, -c.exposure_jitter, c.exposure_jitter);
			for (size_t i = 0; i < base.size(); ++i) {
				frame[i] = uint8_t(std::clamp(float(base[i]) * gain + noise(rng), 0.0f, 255.0f));
			}
			const bool changed = detector.update(frame.data(), width, height, width, 1);
			fired += f > 0 && changed;
		}
		std::printf("static, %-14s fired on %5.1f%% of frames\n", c.name, 100.0 * fired / (frames - 1));
	}
	// A code entering the view: new frames show it shifted by a few pixels.
	for (const int shift : {2, 4, 8, 16, 32}) {
		qrcore::MotionDetector detector;
		std::vector<uint8_t> frame(base.size());
		std::normal_distribution<float> noise(0.0f, 5.0f);
		int fired = 0;
		for (int f = 0; f < frames; ++f) {
			const int offset = (f % 2) * shift;
			for (int y = 0; y < height; ++y) {
				for (int x = 0; x < width; ++x) {
					const int source = std::min(x + offset, width - 1);
					frame[size_t(y) * width + x] = uint8_t(std::clamp(float(base[size_t(y) * width + source]) + noise(rng), 0.0f, 255.0f));
				}
			}
			const bool changed = detector.update(frame.data(), width, height, width, 1);
			fired += f > 0 && changed;
		}
		std::printf("moved %2d px between frames, fired on %5.1f%% of frames\n", shift, 100.0 * fired / (frames - 1));
	}
	qrcore::MotionDetector timing;
	const auto start = std::chrono::steady_clock::now();
	for (int f = 0; f < 200; ++f) timing.update(base.data(), width, height, width, 1);
	std::printf("cost: %.3f ms per frame\n", std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count() / 200);
	return 0;
}

int main(int argc, char **argv) {
	if (argc > 1 && std::string(argv[1]) == "--motion") {
		return check_motion_detector(argc > 2 ? std::atoi(argv[2]) : 60, argc > 3 ? std::atoi(argv[3]) : 1280, argc > 4 ? std::atoi(argv[4]) : 720);
	}
	if (argc > 1 && std::string(argv[1]) == "--false-positives") {
		return count_false_positives(argc > 2 ? std::atoi(argv[2]) : 2000, argc > 3 ? std::atoi(argv[3]) : 1280, argc > 4 ? std::atoi(argv[4]) : 720,
				argc > 5 ? unsigned(std::atoi(argv[5])) : 99u);
	}
	if (argc >= 5 && std::string(argv[1]) == "--render") {
		const int width = argc > 5 ? std::atoi(argv[5]) : 1280;
		const int height = argc > 6 ? std::atoi(argv[6]) : 720;
		Condition condition;
		condition.max_tilt_deg = 35;
		condition.centered = true;
		Rng rng(unsigned(std::atoi(argv[4])));
		std::vector<uint8_t> pixels;
		Renderer(width, height).render(condition, make_code(argv[2]), rng, pixels);
		FILE *file = std::fopen(argv[3], "wb");
		if (!file) return 1;
		std::fprintf(file, "P5\n%d %d\n255\n", width, height);
		std::fwrite(pixels.data(), 1, pixels.size(), file);
		std::fclose(file);
		return 0;
	}
	const int frames = argc > 1 ? std::atoi(argv[1]) : 40;
	const int width = argc > 2 ? std::atoi(argv[2]) : 1280;
	const int height = argc > 3 ? std::atoi(argv[3]) : 720;

	const std::vector<Condition> conditions = [] {
		std::vector<Condition> list;
		const auto add = [&](const char *name, const std::function<void(Condition &)> &edit) {
			Condition c;
			c.name = name;
			edit(c);
			list.push_back(c);
		};
		add("baseline", [](Condition &) {});
		add("tilt 30", [](Condition &c) { c.max_tilt_deg = 30; });
		add("tilt 50", [](Condition &c) { c.max_tilt_deg = 50; });
		add("tilt 65", [](Condition &c) { c.max_tilt_deg = 65; });
		add("small 3px", [](Condition &c) { c.module_px_min = c.module_px_max = 3; });
		add("small 2px", [](Condition &c) { c.module_px_min = c.module_px_max = 2; });
		add("small 1.5px", [](Condition &c) { c.module_px_min = c.module_px_max = 1.5f; });
		add("center 1.5px", [](Condition &c) { c.module_px_min = c.module_px_max = 1.5f; c.centered = true; });
		add("near-filling", [](Condition &c) { c.fill = 0.68f; c.centered = true; });
		add("blur s=1.5", [](Condition &c) { c.blur_sigma = 1.5f; });
		add("blur s=3", [](Condition &c) { c.blur_sigma = 3; });
		add("blur s=5", [](Condition &c) { c.blur_sigma = 5; c.module_px_min = 8; c.module_px_max = 12; });
		add("motion 6px", [](Condition &c) { c.motion_blur_px = 6; });
		add("motion 12px", [](Condition &c) { c.motion_blur_px = 12; c.module_px_min = 8; c.module_px_max = 12; });
		add("dim+noisy", [](Condition &c) { c.light = 0.06f; c.noise_sigma = 8; });
		add("very dim", [](Condition &c) { c.light = 0.015f; c.noise_sigma = 5; });
		add("low contrast", [](Condition &c) { c.paper = 0.55f; c.ink = 0.35f; });
		add("washed out", [](Condition &c) { c.paper = 0.9f; c.ink = 0.65f; c.noise_sigma = 4; });
		add("gradient", [](Condition &c) { c.gradient = 0.9f; });
		add("hard shadow", [](Condition &c) { c.shadow = 0.8f; });
		add("glare", [](Condition &c) { c.glare = 0.6f; });
		add("strong glare", [](Condition &c) { c.glare = 1.2f; });
		add("inverted", [](Condition &c) { c.inverted = true; });
		add("tilt+small", [](Condition &c) { c.max_tilt_deg = 45; c.module_px_min = 3; c.module_px_max = 4; });
		add("tilt+blur+dim", [](Condition &c) { c.max_tilt_deg = 45; c.blur_sigma = 2; c.light = 0.1f; c.noise_sigma = 6; });
		add("hand-held mix", [](Condition &c) { c.max_tilt_deg = 35; c.module_px_min = 3.5f; c.module_px_max = 6; c.blur_sigma = 1.2f; c.motion_blur_px = 3; c.gradient = 0.5f; c.glare = 0.25f; c.light = 0.4f; c.noise_sigma = 5; });
		return list;
	}();

	const std::vector<std::string> payloads = {
		"FF-0042",
		"FOSS-FIGHTER:VIVOSAUR:0137:RARE",
		"https://example.org/fossfighters/card?id=8f14e45fceea167a5a36dedd4bea2543&lang=de&rev=7",
	};

	const std::vector<std::pair<const char *, qrcore::Pass>> passes = {
		{"standard", qrcore::Pass::Standard},
		{"reduced", qrcore::Pass::Reduced},
		{"magnify", qrcore::Pass::Magnified},
		{"flatten", qrcore::Pass::Flattened},
		{"sharpen", qrcore::Pass::Sharpened},
	};

	std::vector<ZXing::BitMatrix> codes;
	for (const auto &payload : payloads) codes.push_back(make_code(payload));

	Renderer renderer(width, height);
	qrcore::Decoder decoder;
	std::vector<uint8_t> pixels;

	std::printf("%dx%d, %d frames per condition. Read rate %% per pass, 'any' = any pass reads that frame.\n\n", width, height, frames);
	std::printf("%-15s", "condition");
	for (const auto &p : passes) std::printf(" %8s", p.first);
	std::printf(" %8s %8s\n", "any", "wrong");

	std::vector<Tally> totals(passes.size());
	int total_any = 0, total_frames = 0;
	for (const Condition &condition : conditions) {
		std::vector<Tally> tally(passes.size());
		int any = 0;
		Rng rng(1234);
		for (int f = 0; f < frames; ++f) {
			const size_t which = size_t(f) % codes.size();
			renderer.render(condition, codes[which], rng, pixels);
			bool read = false;
			for (size_t p = 0; p < passes.size(); ++p) {
				qrcore::Hit hit;
				const auto start = std::chrono::steady_clock::now();
				const bool found = decoder.decode(pixels.data(), width, height, width, passes[p].second, hit);
				tally[p].ms += std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
				if (found) {
					if (hit.text == payloads[which]) {
						++tally[p].reads;
						read = true;
					} else {
						++tally[p].wrong;
						std::fprintf(stderr, "MISREAD [%s / %s] expected '%s' got '%s'\n", condition.name, passes[p].first, payloads[which].c_str(), hit.text.c_str());
					}
				}
			}
			any += read;
		}
		std::printf("%-15s", condition.name);
		int wrong = 0;
		for (size_t p = 0; p < passes.size(); ++p) {
			std::printf(" %8.0f", 100.0 * tally[p].reads / frames);
			totals[p].reads += tally[p].reads;
			totals[p].wrong += tally[p].wrong;
			totals[p].ms += tally[p].ms;
			wrong += tally[p].wrong;
		}
		std::printf(" %8.0f %8d\n", 100.0 * any / frames, wrong);
		std::fflush(stdout);
		total_any += any;
		total_frames += frames;
	}
	std::printf("%-15s", "ALL");
	for (const Tally &t : totals) std::printf(" %8.0f", 100.0 * t.reads / total_frames);
	std::printf(" %8.0f\n%-15s", 100.0 * total_any / total_frames, "avg ms/frame");
	for (const Tally &t : totals) std::printf(" %8.1f", t.ms / total_frames);
	std::printf("\n");
	return 0;
}
