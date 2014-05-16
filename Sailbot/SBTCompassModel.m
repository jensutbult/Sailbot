//
//  SBTCompassModel.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTCompassModel.h"

@implementation SBTCompassModel {
    CLLocationManager *_locationManager;
    CGFloat _lastHeading;
    HeadingUpdateBlock _headingUpdateBlock;
}

- (id)initWithHeadingUpdateBlock:(HeadingUpdateBlock)block {
    self = [super init];
    if (self) {
        if ([CLLocationManager headingAvailable]) {
            _headingUpdateBlock = [block copy];
            _locationManager = [[CLLocationManager alloc] init];
            _locationManager.delegate = self;
            [_locationManager startUpdatingHeading];
        }
    }
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    // simple low pass filter
	CGFloat alpha = 0.1;
    CGFloat currentHeading = newHeading.trueHeading * M_PI / 180.0;
	if (_lastHeading < 0.5 * M_PI && currentHeading > 1.5 * M_PI) {
		_lastHeading = currentHeading * alpha + (2.0 * M_PI + _lastHeading) * (1 - alpha) - 2.0 * M_PI;
	} else {
		_lastHeading = currentHeading * alpha + _lastHeading * (1 - alpha);
	}
    _headingUpdateBlock(_lastHeading);
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
    return YES;
}

@end
