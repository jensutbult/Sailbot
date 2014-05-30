//
//  SBTMatch.c
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-29.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#include "SBTMath.h"
#include <math.h>

float angleSubtractf(float angleOne, float angleTwo) {
    return atan2f(sinf(angleOne - angleTwo), cosf(angleOne - angleTwo));
}

float clampf(float value, float max, float min) {
    return fmin(fmax(min, value), max);
}

float fixAnglef(float angle) {
    if (angle < 0)
        angle += 2 * M_PI;
    else if (angle > 2 * M_PI)
        angle -= 2 * M_PI;
    return angle;
}
