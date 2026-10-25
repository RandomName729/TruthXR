#include <cstdio>
#include <cstdlib>
#include "shader_recompiler/ir/passes/bounded_induction.h"
void assert_fail_impl() { std::abort(); }
[[noreturn]] void unreachable_impl() { std::abort(); }
#define CHECK(x) do { if (!(x)) { std::printf("FAIL line %d\n",__LINE__); std::exit(1); } } while(0)
int main() {
 using namespace Shader;
 Common::ObjectPool<IR::Inst> pool;
 IR::Block entry(pool), header(pool), guard(pool), back(pool), exit(pool);
 Gcn::Block gc{}, bc{}, ec{};
 guard.cfg_block=&gc; back.cfg_block=&bc; exit.cfg_block=&ec;
 gc.cond=IR::Condition::Scc1; gc.branch_true=&bc; gc.branch_false=&ec;
 back.imm_predecessors={&guard};
 auto* phi=&*header.PrependNewInst(header.end(),IR::Opcode::Phi);
 phi->SetFlags(IR::Type::U32);
 auto value=IR::Value{phi};
 guard.AppendNewInst(IR::Opcode::IAdd32,{value,IR::Value{1u}});
 auto* add=&guard.back();
 guard.AppendNewInst(IR::Opcode::SLessThan32,{value,IR::Value{1u}});
 auto* cmp=&guard.back();
 guard.AppendNewInst(IR::Opcode::SetScc,{IR::Value{cmp}});
 phi->AddPhiOperand(&entry,IR::Value{0u}); phi->AddPhiOperand(&back,IR::Value{add});
 auto range=Optimization::BoundedInductionRange(phi);
 CHECK(range && range->first==0 && range->second==1);
 gc.cond=IR::Condition::Scc0;
 CHECK(!Optimization::BoundedInductionRange(phi));
 gc.branch_true=&ec;gc.branch_false=&bc;
 CHECK(Optimization::BoundedInductionRange(phi));
 back.imm_predecessors.push_back(&entry);
 CHECK(!Optimization::BoundedInductionRange(phi));back.imm_predecessors.pop_back();
 add->SetArg(1,IR::Value{2u});CHECK(!Optimization::BoundedInductionRange(phi));add->SetArg(1,IR::Value{1u});
 cmp->SetArg(1,IR::Value{0x7fffffffu});CHECK(!Optimization::BoundedInductionRange(phi));cmp->SetArg(1,IR::Value{1u});
 phi->SetArg(0,IR::Value{2u});CHECK(!Optimization::BoundedInductionRange(phi));phi->SetArg(0,IR::Value{0u});
 guard.AppendNewInst(IR::Opcode::SetScc,{IR::Value{true}});
 CHECK(!Optimization::BoundedInductionRange(phi));
 std::puts("Bounded induction tests passed (valid loops, inverse edge, bypass, stride, overflow, entry and SCC overwrite)");
}
