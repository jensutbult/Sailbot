//
//  SBTSailbotModel.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-10.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTSailbotModel.h"

@implementation SBTSailbotModel

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

- (void)didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData %tu", [data length]);
    if ([data length] < 1)
        return;

    const char *bytes = [data bytes];
    enum SBTSailbotModelHeader command = bytes[0];
    switch (command) {
        case SBTSailbotModelHeaderBoatHeading: {
            float heading;
            memcpy(&heading, &bytes[1], sizeof(float));
            NSLog(@"heading %f", heading);
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
