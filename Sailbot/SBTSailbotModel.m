//
//  SBTSailbotModel.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTSailbotModel.h"

NSString *const SBTSailbotModelStateDidChange = @"SBTSailbotModelStateDidChange";

@implementation SBTSailbotModel {
    int _backingManualSteeringControl;
    int _backingManualSheetControl;
    int _backingSelectedHeading;
}

static SBTSailbotModel *_shared = nil;

+ (SBTSailbotModel *)shared {
    if (_shared == nil) {
        _shared = [[SBTSailbotModel alloc] init];
    }
    return _shared;
}

- (id)init {
    self = [super init];
    if (self) {
        [SBTConnectionManager shared].delegate = self;
    }
    return self;
}

- (void)_setState:(enum SBTSailbotModelState)state {
    if (state != _state) {
        _state = state;
        [[NSNotificationCenter defaultCenter] postNotificationName:SBTSailbotModelStateDidChange object:self];
    }
}

- (void)sendManualControlData {
    NSLog(@"send manual control: %i, %i", _backingManualSteeringControl, _backingManualSheetControl);
    char bytes[1 + 4 + 4];
    bytes[0] = SBTSailbotModelHeaderManualControl;
    int *ptr = (int *)&bytes[1];
    *ptr = _backingManualSteeringControl;
    ptr = (int *)&bytes[1 + sizeof(int)];
    *ptr = _backingManualSheetControl;
    NSData *data = [NSData dataWithBytes:bytes length:1 + 2 * sizeof(int)];
    [[SBTConnectionManager shared] send:data];
}

- (void)sendAutomaticControlData {
    NSLog(@"send automatic control: %i", _backingSelectedHeading);
    char bytes[1 + 4];
    bytes[0] = SBTSailbotModelHeaderAutomaticControl;
    int *ptr = (int *)&bytes[1];
    *ptr = _backingSelectedHeading;
    NSData *data = [NSData dataWithBytes:bytes length:1 + sizeof(int)];
    [[SBTConnectionManager shared] send:data];
}

- (void)setSelectedHeading:(float)selectedHeading {
    int newSelectedHeading = (int)(selectedHeading * 180.0 / M_PI);
    if (newSelectedHeading != _backingSelectedHeading) {
        _backingSelectedHeading = newSelectedHeading;
        [self sendAutomaticControlData];
    }
}

- (float)manualSteeringControl {
    return (float)(_backingManualSteeringControl * 10);
}

- (void)setManualSteeringControl:(float)manualSteeringControl {
    int newSteering = (int)(manualSteeringControl * 10);
    if (newSteering != _backingManualSteeringControl) {
        _backingManualSteeringControl = newSteering;
        [self sendManualControlData];
    }
}

- (float)manualSheetControl {
    return (float)(_backingManualSheetControl * 10);
}

- (void)setManualSheetControl:(float)manualSheetControl {
    int newSheet = (int)(manualSheetControl * 10);
    if (newSheet != _backingManualSheetControl) {
        _backingManualSheetControl = newSheet;
        [self sendManualControlData];
    }
}

- (void)didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData %tu", [data length]);
    if ([data length] < 1)
        return;

    const char *bytes = [data bytes];
    enum SBTSailbotModelHeader command = bytes[0];
    [self _setState:bytes[1]];
    switch (command) {
        case SBTSailbotModelHeaderBoatHeading: {
            float *ptr = (float *)&bytes[2];
            float heading = *ptr;
            NSLog(@"heading %f", heading * 180.0 / M_PI);
            if (_headingUpdateBlock)
                _headingUpdateBlock(heading);
            break;
        }
            //        case SBTSailbotModelHeaderCalibratingIMU: {
            //            [self _setState:SBTSailbotModelStateCalibratingIMU];
            //        }
        default:
            break;
    }
}


- (void)didReceiveHeadingUpdate:(CGFloat)heading {
    if (_headingUpdateBlock) {
        _headingUpdateBlock(heading);
    }
}

@end
