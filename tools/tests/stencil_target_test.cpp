#include <cstdio>
#include <cstdlib>
#include "video_core/renderer_vulkan/liverpool_to_vk.h"
#include "video_core/texture_cache/image_info.h"
void assert_fail_impl() { std::abort(); }
[[noreturn]] void unreachable_impl() { std::abort(); }
// Format lookup is outside the layout calculation under test.
namespace Vulkan::LiverpoolToVK {
vk::Format DepthFormat(AmdGpu::DepthBuffer::ZFormat, AmdGpu::DepthBuffer::StencilFormat) {
    return vk::Format::eD32SfloatS8Uint;
}
}
static void check(bool ok, const char* message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
int main() {
    AmdGpu::DepthBuffer db{};
    db.z_info.format = AmdGpu::DepthBuffer::ZFormat::Z32Float;
    db.stencil_info.format = AmdGpu::DepthBuffer::StencilFormat::Stencil8;
    db.depth_size.pitch_tile_max = 127;
    db.depth_size.height_tile_max = 135;
    db.depth_slice.tile_max = 1024 * 1088 / 64 - 1;
    db.stencil_read_base = 0x200000 >> 8;
    db.stencil_write_base = 0x600000 >> 8;
    AmdGpu::CbDbExtent extent{}; extent.width=960; extent.height=1088;
    VideoCore::ImageInfo stencil(db, 1, 0, extent);
    check(stencil.props.is_stencil_only && stencil.guest_address==0x200000, "stencil-only uses the real stencil address, not zero");
    check(stencil.size.width==960 && stencil.size.height==1088, "retain eye dimensions");
    check(stencil.num_bits==8 && stencil.guest_size==1024*1088, "stencil uploads use byte elements and padded slice size");
    check(stencil.mips_layout[0].pitch==1024 && stencil.mips_layout[0].height==1088, "retain guest tile pitch");
    VideoCore::ImageInfo write(db,1,0,extent,true);
    check(write.guest_address==0x600000 && write.props.is_stencil_only, "write buffer uses stencil write address");
    db.z_info.num_samples=1;
    VideoCore::ImageInfo array(db,2,0,extent);
    check(array.guest_size==1024*1088*4, "account for samples and layers");
    db.z_info.num_samples=0; db.z_read_base=0x800000 >> 8;
    VideoCore::ImageInfo combined(db,1,0,extent);
    check(!combined.props.is_stencil_only && combined.guest_address==0x800000, "combined surface stays keyed by depth");
    check(combined.num_bits==32 && combined.guest_size==1024*1088*4, "combined depth upload is unchanged");
    db.z_read_base=0; db.stencil_read_base=0;
    VideoCore::ImageInfo absent(db,1,0,extent);
    check(!absent.props.is_stencil_only && absent.guest_address==0, "absent planes remain null");
    std::puts("Stencil-only target layout tests passed");
}
