//
//  SBTCompassModel.h
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void (^HeadingUpdateBlock)(CGFloat heading);

@interface SBTCompassModel : NSObject <CLLocationManagerDelegate>

- (id)initWithHeadingUpdateBlock:(HeadingUpdateBlock)block;

@end
