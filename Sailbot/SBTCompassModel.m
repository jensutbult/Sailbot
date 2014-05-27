//
//  SBTCompassModel.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTCompassModel.h"

#define LENGTH 10

@implementation SBTCompassModel {
    CLLocationManager *_locationManager;
    CGFloat _lastHeading;
    AngleUpdateBlock _headingUpdateBlock;
    CGFloat _headings[LENGTH];
    int _position;
    int _size;
    CGPoint _vector;
}

- (id)initWithHeadingUpdateBlock:(AngleUpdateBlock)block {
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


- (void)_add:(CGFloat)heading {
    if (_size < LENGTH) {
        _size++;
    }
    
    if (_position < LENGTH - 1) {
        _position++;
    } else {
        _position = 0;
    }
    
    _vector.x += cosf(heading);
    _vector.y += sinf(heading);
    
    if (_size == LENGTH) {
        CGFloat oldHeading = _headings[_position];
        _vector.x -= cosf(oldHeading);
        _vector.y -= sinf(oldHeading);
    }
    
    _headings[_position] = heading;
}


- (CGFloat)filteredAverage {
    return atan2f(_vector.x / _size, _vector.y / _size);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (newHeading.trueHeading < 0)
        return;
    
    [self _add:newHeading.trueHeading * M_PI / 180.0];
    
    _headingUpdateBlock([self filteredAverage]);
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
    return YES;
}

@end
