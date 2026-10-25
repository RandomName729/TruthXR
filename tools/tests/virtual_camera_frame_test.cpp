#include "core/libraries/camera/virtual_frame.h"
#include "core/libraries/vr_tracker/virtual_camera_marker.h"
#include <cassert>
#include <cstdio>
#include <limits>

int main() {
    using namespace Libraries::Camera;
    const auto image = VirtualBlackYuy2(1280 * 800);
    assert(image.size() == 1280 * 800 * 2);
    for (std::size_t i = 0; i < image.size(); i += 4) {
        assert(image[i] == 16 && image[i + 1] == 128);
        assert(image[i + 2] == 16 && image[i + 3] == 128);
        // BT.601 conversion must produce neutral black, not green.
        const int y = image[i] - 16, u = image[i + 1] - 128, v = image[i + 3] - 128;
        assert(298 * y + 409 * v == 0);
        assert(298 * y - 100 * u - 208 * v == 0);
        assert(298 * y + 516 * u == 0);
    }
    assert(VirtualFrameBytes(1280, 800, 0) == image.size());
    assert(VirtualFrameBytes(1280, 800, 1) == image.size());
    assert(VirtualFrameBytes(1280, 800, 2) == 1280 * 800);
    assert(VirtualFrameBytes(640, 400, 3) == 640 * 400 * 2);
    assert(VirtualFrameBytes(640, 400, 4) == 640 * 400);
    assert(VirtualFrameBytes(640, 400, 0x10) == 0);
    assert(VirtualFrameBytes(640, 400, 0xff) == 0);
    using Libraries::VrTracker::ProjectVirtualCameraMarker;
    const auto centred = ProjectVirtualCameraMarker(0, 0, 1.5f);
    assert(centred && centred->x == 0.5f && centred->y == 0.5f);
    // The live calibration pose must land in the guest's observed box:
    // x = 0.3..0.7, y = 0.2..0.7. Previously both marker counts were zero.
    const auto observed = ProjectVirtualCameraMarker(0.09775f, 0.01148f, 1.43307f);
    assert(observed && observed->x > 0.3f && observed->x < 0.7f &&
           observed->y > 0.2f && observed->y < 0.7f);
    const auto moved = ProjectVirtualCameraMarker(0.5f, 0.25f, 1.5f);
    assert(moved && moved->x > centred->x && moved->y < centred->y);
    assert(!ProjectVirtualCameraMarker(0, 0, 0));
    assert(!ProjectVirtualCameraMarker(0, 0, -1));
    assert(!ProjectVirtualCameraMarker(2, 0, 1));
    assert(!ProjectVirtualCameraMarker(0, 1, 1));
    assert(!ProjectVirtualCameraMarker(std::numeric_limits<float>::quiet_NaN(), 0, 1));
    assert(!ProjectVirtualCameraMarker(0, 0, std::numeric_limits<float>::infinity()));
    std::puts("Virtual camera frame format tests passed");
}
