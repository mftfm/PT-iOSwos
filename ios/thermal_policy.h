#pragma once
#include <algorithm>
namespace pt::ios {
// NSProcessInfoThermalState: nominal=0, fair=1, serious=2, critical=3.
struct ThermalPolicy {
    bool reduced = false;
    double recover_after = 0;
    int FrameLimit(int requested, int thermal, bool low_power, double now) {
        if (thermal >= 2 || low_power) {
            reduced = true;
            recover_after = now + 60;
        } else if (reduced && thermal == 0 && now >= recover_after) {
            reduced = false;
        }
        // A stable 60 Hz target is preferable to chasing 120 Hz on a
        // sustained 3D workload; serious thermal state or Low Power Mode drops
        // to 30 Hz, then recovers only after a full cool-down interval.
        return std::min(requested > 0 ? requested : 60, reduced ? 30 : 60);
    }
};
}
