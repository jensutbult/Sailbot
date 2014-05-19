//
//  SBTConnectionManager.h
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-09.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RFduinoManagerDelegate.h"
#import "RFduinoDelegate.h"

extern NSString *const SBTConnectionManagerDidConnect;
extern NSString *const SBTConnectionManagerDidDisconnect;

@protocol SBTConnectionManagerDelegate <NSObject>

- (void)didReceiveData:(NSData *)data;

@end


@interface SBTConnectionManager : NSObject <RFduinoManagerDelegate, RFduinoDelegate>

+ (SBTConnectionManager *)shared;

- (BOOL)isConnectedToSailbot;
- (void)send:(NSData *)data;

@property (nonatomic, weak) id<SBTConnectionManagerDelegate> delegate;

@end
