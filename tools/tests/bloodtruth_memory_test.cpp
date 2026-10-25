#include "core/libraries/kernel/bloodtruth_memory_compat.h"
#include <cstdio>

using Libraries::Kernel::IsBloodTruthTemporaryAlias;
static_assert(IsBloodTruthTemporaryAlias("CUSA11108", 0, 0x10000, 2, 0x80));
static_assert(!IsBloodTruthTemporaryAlias("CUSA04508", 0, 0x10000, 2, 0x80));
static_assert(!IsBloodTruthTemporaryAlias("CUSA11108", 0x10000, 0x10000, 2, 0x80));
static_assert(!IsBloodTruthTemporaryAlias("CUSA11108", 0, 0x4000, 2, 0x80));
static_assert(!IsBloodTruthTemporaryAlias("CUSA11108", 0, 0x10000, 0x32, 0x80));
static_assert(!IsBloodTruthTemporaryAlias("CUSA11108", 0, 0x10000, 2, 0x90));
int main() { std::puts("Blood & Truth temporary alias scope tests passed"); }
