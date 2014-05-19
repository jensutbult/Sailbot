//
//  SBTConnectionManager.h
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-09.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTConnectionManager.h"
#import "RfduinoManager.h"
#import "RFduino.h"

NSString *const SBTConnectionManagerDidConnect = @"SBTConnectionManagerDidConnect";
NSString *const SBTConnectionManagerDidDisconnect = @"SBTConnectionManagerDidDisconnect";

@implementation SBTConnectionManager {
    RFduinoManager *_rfduinoManager;
    RFduino *_rfduino;
}


static SBTConnectionManager *_shared = nil;

+ (SBTConnectionManager *)shared {
    if (_shared == nil) {
        _shared = [[SBTConnectionManager alloc] init];
    }
    return _shared;
}

- (id)init {
    self = [super init];
    if (self) {
        _rfduinoManager = [RFduinoManager sharedRFduinoManager];
        _rfduinoManager.delegate = self;
        [_rfduinoManager startScan];
    }
    return self;
}

- (BOOL)isConnectedToSailbot {
    return _rfduino != nil;
}


#pragma mark - RfduinoDiscoveryDelegate methods

- (void)didDiscoverRFduino:(RFduino *)rfduino {

    NSString *advertising = @"";
    if (rfduino.advertisementData) {
        advertising = [[NSString alloc] initWithData:rfduino.advertisementData encoding:NSUTF8StringEncoding];
    }
    
    NSLog(@"Found: %@ (%@)", advertising, rfduino);

    if (rfduino && [advertising isEqualToString:@"Sailbot"] && !rfduino.outOfRange) {
        [_rfduinoManager connectRFduino:rfduino];
    }
}

- (void)didUpdateDiscoveredRFduino:(RFduino *)rfduino {
    NSLog(@"%@", rfduino);
}

- (void)didConnectRFduino:(RFduino *)rfduino {
    [[NSNotificationCenter defaultCenter] postNotificationName:SBTConnectionManagerDidConnect object:self];
    NSLog(@"%@", rfduino);
    [_rfduinoManager stopScan];
}

- (void)didLoadServiceRFduino:(RFduino *)rfduino {
    NSLog(@"%@", rfduino);
    _rfduino = rfduino;
    _rfduino.delegate = self;
}

- (void)didDisconnectRFduino:(RFduino *)rfduino {
    [[NSNotificationCenter defaultCenter] postNotificationName:SBTConnectionManagerDidDisconnect object:self];
    NSLog(@"%@", rfduino);
    _rfduino = nil;
    [_rfduinoManager startScan];
}

- (void)send:(NSData *)data {
    [_rfduino send:data];
}

#pragma mark - RFduinoDelegate method

- (void)didReceive:(NSData *)data {
    [_delegate didReceiveData:data];
}


@end
