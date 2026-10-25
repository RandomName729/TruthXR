#include "core/vr/stereo_layout.h"
#include <cstdio>
#include <limits>

#define CHECK(x) do { if (!(x)) { std::printf("FAIL %d: %s\n", __LINE__, #x); return 1; } } while (0)
int main() {
    using Core::Vr::OverlaySourceUv;
    const std::array<float, 4> base{0.4f, 0.5f, 0.51f, 0.5f};
    auto same = OverlaySourceUv(base, base);
    CHECK(same && ((*same) == std::array<float, 4>{1, 1, 0, 0}));
    const std::array<float, 4> overlay{0.2f, 0.25f, 0.4f, 0.6f};
    auto transformed = OverlaySourceUv(base, overlay);
    CHECK(transformed);
    for (int axis = 0; axis < 2; ++axis) {
        const float tangent = -0.7f;
        const float uv = tangent * base[axis] + base[axis + 2];
        const float expected = tangent * overlay[axis] + overlay[axis + 2];
        CHECK(std::abs(uv * (*transformed)[axis] + (*transformed)[axis + 2] - expected) < 1e-6f);
    }
    CHECK(!OverlaySourceUv({0, 0, 0, 0}, base));
    CHECK(!OverlaySourceUv(base, {-1, 1, 0, 0}));
    CHECK(!OverlaySourceUv(base, {1, 1, std::numeric_limits<float>::infinity(), 0}));
    std::puts("Overlay projection tests passed");
}
