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
    int _backingAutomaticHeading;
    int _lastSentWindDirection;
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
        [[NSNotificationCenter defaultCenter] addObserverForName:SBTConnectionManagerDidConnect object:[SBTConnectionManager shared] queue:nil usingBlock:^(NSNotification *note) {
            [self _setState:SBTSailbotModelStateConnected];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:SBTConnectionManagerDidDisconnect object:[SBTConnectionManager shared] queue:nil usingBlock:^(NSNotification *note) {
            [self _setState:SBTSailbotModelStateDisconnected];
        }];
    }
    return self;
}

- (void)_setState:(enum SBTSailbotModelState)state {
    if (state != _state) {
        _state = state;
        [[NSNotificationCenter defaultCenter] postNotificationName:SBTSailbotModelStateDidChange object:self];
    }
}

- (void)sendCalibrateWind:(float)direction {
    int newWindDirection = (int)(direction * 180.0 / M_PI);
    if (newWindDirection != _lastSentWindDirection) {
        _lastSentWindDirection = newWindDirection;
        char bytes[1 + 4];
        bytes[0] = SBTSailbotModelHeaderWindDirection;
        int *ptr = (int *)&bytes[1];
        *ptr = _lastSentWindDirection\
        ;
        NSLog(@"Send calibrate wind: %i", *ptr);
        NSData *data = [NSData dataWithBytes:bytes length:1 + sizeof(int)];
        [[SBTConnectionManager shared] send:data];
    }
}

- (void)sendManualControlData {
    NSLog(@"Send manual control: %i, %i", _backingManualSteeringControl, _backingManualSheetControl);
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
    NSLog(@"Send automatic control: %i", _backingAutomaticHeading);
    char bytes[1 + 4];
    bytes[0] = SBTSailbotModelHeaderAutomaticControl;
    int *ptr = (int *)&bytes[1];
    *ptr = _backingAutomaticHeading;
    NSData *data = [NSData dataWithBytes:bytes length:1 + sizeof(int)];
    [[SBTConnectionManager shared] send:data];
}

- (void)setAutomaticHeading:(float)automaticHeading {
    int newAutomaticHeading = (int)(automaticHeading * 180.0 / M_PI);
    if (newAutomaticHeading != _backingAutomaticHeading) {
        _backingAutomaticHeading = newAutomaticHeading;
        [self sendAutomaticControlData];
    }
}

- (float)automaticHeading {
    return (float)(_backingAutomaticHeading * M_PI / 180.0);
}

- (float)manualSteeringControl {
    return (float)(_backingManualSteeringControl / 10.0);
}

- (void)setManualSteeringControl:(float)manualSteeringControl {
    int newSteering = (int)(manualSteeringControl * 10);
    if (newSteering != _backingManualSteeringControl) {
        _backingManualSteeringControl = newSteering;
        [self sendManualControlData];
    }
}

- (float)manualSheetControl {
    return (float)(_backingManualSheetControl / 10.0);
}

- (void)setManualSheetControl:(float)manualSheetControl {
    int newSheet = (int)(manualSheetControl * 10);
    if (newSheet != _backingManualSheetControl) {
        _backingManualSheetControl = newSheet;
        [self sendManualControlData];
    }
}

- (NSString *)_stringFromHeader:(char)header {
    NSArray *_headers = @[@"NO STATE",
                          @"Connected",
                          @"Disconnected",
                          @"CalibratingIMU",
                          @"NoIMU",
                          @"WindNotCalibrated",
                          @"ManualControl",
                          @"AutomaticControl",
                          @"RecoveryMode",
                          ];
    return _headers[header];
}

- (void)didReceiveData:(NSData *)data {
    if ([data length] < 1)
        return;
    const char *bytes = [data bytes];
    enum SBTSailbotModelHeader command = bytes[0];
    if (command != SBTSailbotModelHeaderBoatState)
        return;
    
    NSLog(@"%@ (%tu bytes)", [self _stringFromHeader:bytes[1]], [data length]);
    [self _setState:bytes[1]];
    
    // Boat heading
    float *ptr = (float *)&bytes[2];
    _boatHeading = *ptr;
    if (_headingUpdateBlock)
        _headingUpdateBlock(_boatHeading);
    NSLog(@"Boat heading: %f", _boatHeading * 180.0 / M_PI);
    
    // Boat wind direction
    ptr = (float *)&bytes[6];
    _windDirection = *ptr;
    if (_windDirection < 0) {
        NSLog(@"No wind direction");
    } else {
        if (_windUpdateBlock)
            _windUpdateBlock(_windDirection);
        NSLog(@"Boat wind direction: %f", _windDirection * 180.0 / M_PI);
    }
    
    // Boat rudder
    ptr = (float *)&bytes[10];
    _boatRudder = *ptr;
    NSLog(@"Boat rudder: %f", _boatRudder);
    
    // Boat sheet
    ptr = (float *)&bytes[14];
    _boatSheet = *ptr;
    NSLog(@"Boat sheet: %f", _boatSheet);
    
    NSLog(@"==============================");
}


- (void)didReceiveHeadingUpdate:(CGFloat)heading {
    if (_headingUpdateBlock) {
        _headingUpdateBlock(heading);
    }
}

@end
