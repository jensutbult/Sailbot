//
//  SBTSailbotModel.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTSailbotModel.h"

@implementation SBTSailbotModel {
    int _backingManualSteeringControl;
    int _backingManualSheetControl;
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

- (void)_sendManualControlData {
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

- (float)manualSteeringControl {
    return (float)(_backingManualSteeringControl * 10);
}

- (void)setManualSteeringControl:(float)manualSteeringControl {
    int newSteering = (int)(manualSteeringControl * 10);
    if (newSteering != _backingManualSteeringControl) {
        _backingManualSteeringControl = newSteering;
        [self _sendManualControlData];
    }
}

- (float)manualSheetControl {
    return (float)(_backingManualSheetControl * 10);
}

- (void)setManualSheetControl:(float)manualSheetControl {
    int newSheet = (int)(manualSheetControl * 10);
    if (newSheet != _backingManualSheetControl) {
        _backingManualSheetControl = newSheet;
        [self _sendManualControlData];
    }
}

- (void)didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData %tu", [data length]);
    if ([data length] < 1)
        return;

    const char *bytes = [data bytes];
    enum SBTSailbotModelHeader command = bytes[0];
    switch (command) {
        case SBTSailbotModelHeaderBoatHeading: {
            float *ptr = (float *)&bytes[1];
            float heading = *ptr;
            NSLog(@"heading %f", heading * 180.0 / M_PI);
            if (_headingUpdateBlock)
                _headingUpdateBlock(heading);
            break;
        }
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
