// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <cstdint>
#include <string_view>

namespace Libraries::Kernel {

// Compatibility workaround, not a general model of PS4 direct-memory alias rules.
// Only the resource loader's temporary CPU table mapping is eligible.
constexpr bool IsBloodTruthTemporaryAlias(std::string_view serial, std::uint64_t address,
                                         std::uint64_t size, int protection, int flags) {
    return serial == "CUSA11108" && address == 0 && size == 0x10000 && protection == 2 &&
           flags == 0x80;
}

} // namespace Libraries::Kernel
