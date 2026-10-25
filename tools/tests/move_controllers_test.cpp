#include <cstdio>
#include "core/vr/vr_runtime.h"
#include "core/libraries/move/move.cpp"
static std::array<Core::Vr::MoveState, 2> samples;
static std::array<unsigned char, 2> rumble;
namespace Core::Vr {
Runtime::Runtime() = default;
Runtime& Runtime::Instance() { static Runtime runtime; return runtime; }
MoveState Runtime::GetMove(u32 hand) { return samples.at(hand); }
void Runtime::SetMoveVibration(u32 hand,u8 intensity) { rumble.at(hand)=intensity; }
void Runtime::ReleaseMoves() { samples={}; rumble={}; }
Quat Conjugate(const Quat& q) { return {-q.x,-q.y,-q.z,q.w}; }
}
#define CHECK(x) do { if(!(x)) { std::printf("FAIL line %d: %s\n",__LINE__,#x); return 1; } } while(0)
int main() {
 using namespace Libraries::Move;
 OrbisMoveData data{};
 CHECK(sceMoveReadStateLatest(0,&data)==ORBIS_MOVE_ERROR_NOT_INIT);
 CHECK(sceMoveInit()==0);
 CHECK(!HasOpenControllerPair());
 int left=sceMoveOpen(1,0,0);
 CHECK(!HasOpenControllerPair());
 int right=sceMoveOpen(1,0,1);
 CHECK(HasOpenControllerPair());
 CHECK(left>0 && right>0 && left!=right);
 CHECK(HandForHandle(left)==0 && HandForHandle(right)==1);
 CHECK(sceMoveOpen(1,0,0)==ORBIS_MOVE_ERROR_ALREADY_OPENED);
 CHECK(sceMoveOpen(1,0,2)==ORBIS_MOVE_ERROR_INVALID_PORT);
 samples[0].connected=true; samples[0].buttons=0x44; samples[0].trigger=240; samples[0].timestamp=100;
 samples[1].connected=true; samples[1].buttons=0x20; samples[1].trigger=10; samples[1].timestamp=200;
 CHECK(sceMoveReadStateLatest(left,&data)==0 && data.button_data.button_data==0x44 && data.button_data.trigger_data==240);
 CHECK(sceMoveReadStateLatest(right,&data)==0 && data.button_data.button_data==0x20 && data.button_data.trigger_data==10);
 int count=-1;
 CHECK(sceMoveReadStateRecent(left,100,&data,&count)==0 && count==0);
 CHECK(sceMoveReadStateRecent(right,100,&data,&count)==0 && count==1 && data.timestamp==200);
 CHECK(sceMoveReadStateLatest(left,nullptr)==ORBIS_MOVE_ERROR_INVALID_ARG);
 CHECK(sceMoveSetVibration(left,50)==0 && rumble[0]==50 && rumble[1]==0);
 CHECK(sceMoveSetVibration(right,80)==0 && rumble[0]==50 && rumble[1]==80);
 samples[0].connected=false;
 CHECK(sceMoveReadStateLatest(left,&data)==ORBIS_MOVE_ERROR_NO_CONTROLLER_CONNECTED);
 CHECK(sceMoveReadStateLatest(right,&data)==0);
 CHECK(sceMoveClose(left)==0 && rumble[0]==0 && HandForHandle(left)==-1);
 CHECK(!HasOpenControllerPair());
 CHECK(sceMoveReadStateLatest(left,&data)==ORBIS_MOVE_ERROR_INVALID_HANDLE);
 CHECK(sceMoveOpen(1,0,0)!=left);
 CHECK(HasOpenControllerPair());
 CHECK(sceMoveTerm()==0 && HandForHandle(right)==-1);
 CHECK(!HasOpenControllerPair());
 CHECK(sceMoveInit()==0 && sceMoveOpen(1,0,0)>0);
 puts("Move tests passed: independent hands, triggers, haptics, timestamps, disconnect, invalid handles, reopen and reinit");
}
