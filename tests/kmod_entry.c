#include <mach/kmod.h>
extern kern_return_t Thunderbolt3Unblocker_start(kmod_info_t *, void *);
extern kern_return_t Thunderbolt3Unblocker_stop(kmod_info_t *, void *);
KMOD_EXPLICIT_DECL(es.govost.ryan.Thunderbolt3Unblocker, "1.1.0",
                   Thunderbolt3Unblocker_start, Thunderbolt3Unblocker_stop)
__private_extern__ kmod_start_func_t *_realmain = Thunderbolt3Unblocker_start;
__private_extern__ kmod_stop_func_t *_antimain = Thunderbolt3Unblocker_stop;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
