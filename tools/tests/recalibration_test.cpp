#include "core/libraries/vr_tracker/recalibration_state.h"
#include "core/libraries/vr_tracker/virtual_camera_result.h"
#include <cstring>
#include <cstdio>
#define CHECK(x) do { if (!(x)) { std::printf("FAIL %d\n", __LINE__); return 1; } } while(0)
int main() {
    using namespace Libraries::VrTracker;
    OrbisVrTrackerResultData result{};
    const auto marker = ProjectVirtualCameraMarker(0.06357f, -0.000068f, 1.52042f);
    CHECK(marker);
    WriteVirtualCameraMarker(result, *marker, 1234);
    // Reproduce the guest's byte-level reads, rather than checking only the
    // projection helper. The previous candidate left rx/ry zero.
    for (unsigned camera = 0; camera < 2; ++camera) {
        int count{}; float xy[2]{};
        const auto* bytes = reinterpret_cast<const unsigned char*>(&result);
        std::memcpy(&count, bytes + 0x1d8 + camera * 4, sizeof(count));
        std::memcpy(xy, bytes + 0x1f8 + camera * 0x200, sizeof(xy));
        CHECK(count == 1);
        CHECK(xy[0] >= 0.3f && xy[0] <= 0.7f);
        CHECK(xy[1] >= 0.2f && xy[1] <= 0.7f);
    }
    CHECK(result.timestamp_of_led_result == 1234);
    Libraries::VrTracker::RecalibrationState s;
    CHECK(!s.IsActive(0, 0)); CHECK(!s.IsActive(0, 1));
    s.Begin(200);
    CHECK(s.IsActive(300, 0)); CHECK(!s.IsActive(300, 0));
    CHECK(s.IsActive(400, 1)); CHECK(!s.IsActive(400, 1));
    s.Begin(600);
    CHECK(s.IsActive(500, 0)); CHECK(s.IsActive(500, 1));
    CHECK(s.IsActive(599, 1)); CHECK(!s.IsActive(600, 1));
    CHECK(!s.IsActive(600, 0)); CHECK(!s.IsActive(600, 32));
    std::puts("Independent calibration transition tests passed");
}
