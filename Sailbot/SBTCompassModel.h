//
//  SBTCompassModel.h
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void (^AngleUpdateBlock)(CGFloat angle);

@interface SBTCompassModel : NSObject <CLLocationManagerDelegate>

- (id)initWithHeadingUpdateBlock:(AngleUpdateBlock)block;
- (CGFloat)filteredAverage;

@end
