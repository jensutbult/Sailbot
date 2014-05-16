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
    SBTSailbotModelHeaderBoatHeading = 1,
    SBTSailbotModelHeaderAutomaticControl,
    SBTSailbotModelHeaderManualControl,
    SBTSailbotModelHeaderConfiguration,
};

// receive - current heading
// send - configuration data
// send - selected heading
// send - rudder angle
// send - sheet value


typedef void (^HeadingUpdateBlock)(CGFloat heading);

@interface SBTSailbotModel : NSObject <SBTConnectionManagerDelegate>

+ (SBTSailbotModel *)shared;

@property (nonatomic, copy) HeadingUpdateBlock headingUpdateBlock;
@property (nonatomic, assign) float selectedHeading;

@end
