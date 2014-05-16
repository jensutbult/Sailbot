//
//  SBTViewController.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-09.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "SBTViewController.h"
#import "SBTSailbotModel.h"
#import "SBTCompassModel.h"
#import "SBTOneFingerRotationGestureRecognizer.h"

@interface SBTViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *boatImageView;

@end

@implementation SBTViewController {
    SBTSailbotModel *_sailbot;
    SBTCompassModel *_compass;
    __weak IBOutlet UIImageView *_headingImageView;
    __weak IBOutlet UIView *_compassView;
    __weak IBOutlet NSLayoutConstraint *_headingHorizontalConstraint;
    __weak IBOutlet NSLayoutConstraint *_headingVerticalConstraint;
    CGFloat _headingOffset;
    CGFloat _heading;
    CGFloat _compassHeading;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _compass = [[SBTCompassModel alloc] initWithHeadingUpdateBlock:^(CGFloat heading) {
        [UIView animateWithDuration:0.3 animations:^{
            _compassHeading = heading;
            _compassView.transform = CGAffineTransformMakeRotation(-heading);
            [self _rotateHeading:nil];
        }];
    }];
    _sailbot = [SBTSailbotModel shared];
    __weak SBTViewController *__self = self;
    _sailbot.headingUpdateBlock = ^(CGFloat heading) {
        [UIView animateWithDuration:0.3 animations:^{
            __self.boatImageView.transform = CGAffineTransformMakeRotation(heading);
        }];
    };
    
    _headingOffset = _headingHorizontalConstraint.constant;
    SBTOneFingerRotationGestureRecognizer *rotationGesture = [[SBTOneFingerRotationGestureRecognizer alloc] initWithTarget:self action:@selector(_rotateHeading:)];
    [_headingImageView addGestureRecognizer:rotationGesture];
}

- (void)_rotateHeading:(SBTOneFingerRotationGestureRecognizer *)rotationGesture {
    _heading += rotationGesture ? rotationGesture.rotation : 0;
    [SBTSailbotModel shared].selectedHeading = _heading;
    NSLog(@"Current heading: %f", _heading * 180 / M_PI);
    _headingVerticalConstraint.constant = sinf(_heading - _compassHeading) * _headingOffset;
    _headingHorizontalConstraint.constant = cosf(_heading - _compassHeading) * _headingOffset;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return self.interfaceOrientation != UIDeviceOrientationPortrait;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self setNeedsStatusBarAppearanceUpdate];
}


@end
