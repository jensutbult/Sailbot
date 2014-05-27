//
//  SBTSailbotModel.h
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBTConnectionManager.h"

NS_ENUM(char, SBTSailbotModelHeader) {
    SBTSailbotModelHeaderBoatState = 1,
    SBTSailbotModelHeaderAutomaticControl,
    SBTSailbotModelHeaderManualControl,
    SBTSailbotModelHeaderConfiguration,
    SBTSailbotModelHeaderWindDirection,
};

NS_ENUM(NSUInteger, SBTSailbotModelState) {
    SBTSailbotModelStateConnected = 1,
    SBTSailbotModelStateDisconnected,
    SBTSailbotModelStateCalibratingIMU,
    SBTSailbotModelStateNoIMU,
    SBTSailbotModelStateWindNotCalibrated,
    SBTSailbotModelStateManualControl,
    SBTSailbotModelStateAutomaticControl,
    SBTSailbotModelStateRecoveryMode,
};

extern NSString *const SBTSailbotModelStateDidChange;


// receive - current heading
// send - configuration data
// send - selected heading
// send - rudder angle
// send - sheet value


typedef void (^AngleUpdateBlock)(CGFloat heading);

@interface SBTSailbotModel : NSObject <SBTConnectionManagerDelegate>

+ (SBTSailbotModel *)shared;
- (void)calibrateWind:(int)direction;
- (void)sendManualControlData;
- (void)sendAutomaticControlData;

@property (nonatomic, readonly) enum SBTSailbotModelState state;
@property (nonatomic, copy) AngleUpdateBlock headingUpdateBlock;
@property (nonatomic, copy) AngleUpdateBlock windUpdateBlock;
@property (nonatomic, assign) float automaticHeading;
@property (nonatomic, assign) float manualSheetControl;
@property (nonatomic, assign) float manualSteeringControl;

@property (nonatomic, readonly) float boatHeading;
@property (nonatomic, readonly) float boatWindDirection;
@property (nonatomic, readonly) float boatRudder;
@property (nonatomic, readonly) float boatSheet;

@end
