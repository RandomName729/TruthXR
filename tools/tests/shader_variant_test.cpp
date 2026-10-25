#include "video_core/renderer_vulkan/vk_pipeline_cache.h"
#include <cstdio>
#define CHECK(x) do { if (!(x)) { std::printf("FAIL %d: %s\n", __LINE__, #x); return 1; } } while (0)
int main() {
    Vulkan::Program program;
    auto depth = std::make_unique<Shader::Info>();
    auto color = std::make_unique<Shader::Info>();
    color->buffers.emplace_back();
    Shader::StageSpecialization a{}, b{};
    a.info = depth.get(); b.info = color.get();
    b.buffers.emplace_back();
    CHECK(!(a == b)); CHECK(!(b == a));
    Shader::StageSpecialization invalid{};
    CHECK(!(a == invalid));
    program.modules.push_back({{}, std::move(depth), std::move(a)});
    program.modules.push_back({{}, std::move(color), std::move(b)});
    auto* stable = program.modules[1].info.get();
    for (int i=0;i<32;++i) program.modules.push_back({{},std::make_unique<Shader::Info>(),{}});
    CHECK(program.modules[1].info.get()==stable);
    CHECK(program.modules[1].spec.info==stable);
    CHECK(program.modules[0].info->buffers.empty());
    CHECK(program.modules[1].info->buffers.size()==1);
    std::puts("Shader variant metadata tests passed");
}
