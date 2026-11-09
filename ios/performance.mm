#import <UIKit/UIKit.h>
#include <atomic>
#include <SDL3/SDL.h>
#include "thermal_policy.h"

static std::atomic<bool> g_ios_memory_warning{false};

@interface PTIOSMemoryWarningObserver : NSObject
@end

@implementation PTIOSMemoryWarningObserver
+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification* notification) {
        g_ios_memory_warning.store(true, std::memory_order_relaxed);
    }];
}
@end

extern "C" bool PTIOSConsumeMemoryWarning() {
    return g_ios_memory_warning.exchange(false, std::memory_order_acq_rel);
}

int PTIOSFrameLimit(int requested) {
    static pt::ios::ThermalPolicy policy;
    static double next_poll = 0;
    static int thermal = 0;
    static bool low_power = false;
    const double now = SDL_GetTicksNS() * 1e-9;
    if (now >= next_poll) {
        NSProcessInfo* info = NSProcessInfo.processInfo;
        thermal = static_cast<int>(info.thermalState);
        low_power = info.lowPowerModeEnabled;
        next_poll = now + 1;
    }
    return policy.FrameLimit(requested, thermal, low_power, now);
}
