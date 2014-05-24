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
    SBTSailbotModelHeaderState = 1,
    SBTSailbotModelHeaderBoatHeading,
    SBTSailbotModelHeaderAutomaticControl,
    SBTSailbotModelHeaderManualControl,
    SBTSailbotModelHeaderConfiguration,
    SBTSailbotModelHeaderWindDirection,
};

NS_ENUM(NSUInteger, SBTSailbotModelState) {
    SBTSailbotModelStateCalibratingIMU = 1,
    SBTSailbotModelStateNoIMU,
    SBTSailbotModelStateManualControl,
    SBTSailbotModelStateAutomaticControl,
};

extern NSString *const SBTSailbotModelStateDidChange;


// receive - current heading
// send - configuration data
// send - selected heading
// send - rudder angle
// send - sheet value


typedef void (^HeadingUpdateBlock)(CGFloat heading);

@interface SBTSailbotModel : NSObject <SBTConnectionManagerDelegate>

+ (SBTSailbotModel *)shared;
- (void)sendManualControlData;
- (void)sendAutomaticControlData;

@property (nonatomic, readonly) enum SBTSailbotModelState state;
@property (nonatomic, copy) HeadingUpdateBlock headingUpdateBlock;
@property (nonatomic, assign) float selectedHeading;
@property (nonatomic, assign) float manualSheetControl;
@property (nonatomic, assign) float manualSteeringControl;

@end
