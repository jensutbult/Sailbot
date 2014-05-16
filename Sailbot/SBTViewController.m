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
#import "UIView+SBTShortcuts.h"

@interface SBTViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *boatImageView;

@end

@implementation SBTViewController {
    SBTSailbotModel *_sailbot;
    SBTCompassModel *_compass;
    __weak IBOutlet UIImageView *_headingImageView;
    __weak IBOutlet UIView *_compassView;
    __weak IBOutlet NSLayoutConstraint *_compassWidthConstraint;
    __weak IBOutlet NSLayoutConstraint *_compassHeightConstraint;
    __weak IBOutlet NSLayoutConstraint *_headingHorizontalConstraint;
    __weak IBOutlet NSLayoutConstraint *_headingVerticalConstraint;
    __weak IBOutlet UIImageView *_sheetControlImageView;
    __weak IBOutlet UIImageView *_sheetScaleImageView;
    __weak IBOutlet UIImageView *_tillerImageView;
    CGFloat _compassViewSize;
    CGFloat _headingOffset;
    CGFloat _heading;
    CGFloat _compassHeading;
    CGFloat _compassCompensation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _compass = [[SBTCompassModel alloc] initWithHeadingUpdateBlock:^(CGFloat heading) {
        [UIView animateWithDuration:0.3 animations:^{
            _compassHeading = heading;
            _compassView.transform = CGAffineTransformMakeRotation([self _compensatedCompass]);
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
    _compassViewSize = _compassHeightConstraint.constant;
    
    SBTOneFingerRotationGestureRecognizer *rotationGesture = [[SBTOneFingerRotationGestureRecognizer alloc] initWithTarget:self action:@selector(_rotateHeading:)];
    [_headingImageView addGestureRecognizer:rotationGesture];
    
    _boatImageView.layer.anchorPoint = CGPointMake(0.5, 0.5);
}

- (void)_rotateHeading:(SBTOneFingerRotationGestureRecognizer *)rotationGesture {
    _heading += rotationGesture ? rotationGesture.rotation : 0;
    if (_heading < 0)
        _heading += 2 * M_PI;
    if (_heading > 2 * M_PI)
        _heading -= 2 * M_PI;
    
    [SBTSailbotModel shared].selectedHeading = _heading;
    _headingVerticalConstraint.constant = sinf(_heading + _compassHeading) * _headingOffset;
    _headingHorizontalConstraint.constant = cosf(_heading + _compassHeading) * _headingOffset;
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
    if (toInterfaceOrientation == UIDeviceOrientationPortrait) {
        _compassCompensation = 0;
    } else if (toInterfaceOrientation == UIDeviceOrientationLandscapeLeft) {
        _compassCompensation = -M_PI / 2.0;
    } else {
        _compassCompensation = M_PI / 2.0;
    }
    
    [self setNeedsStatusBarAppearanceUpdate];
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (fromInterfaceOrientation == UIDeviceOrientationPortrait) {
        // Switch to landscape mode (manual control)
        [UIView animateWithDuration:0.3 animations:^{
            _headingImageView.alpha = 0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 animations:^{
                _compassHeightConstraint.constant = 250;
                _compassWidthConstraint.constant = 250;
                [_compassView setNeedsUpdateConstraints];
                [_compassView layoutIfNeeded];
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    _tillerImageView.alpha = 1;
                    _sheetScaleImageView.alpha = 1;
                    _sheetControlImageView.alpha = 1;
                }];
            }];
        }];
    } else {
        // Switch to portrait mode (automatic)
        [UIView animateWithDuration:0.3 animations:^{
            _tillerImageView.alpha = 0;
            _sheetScaleImageView.alpha = 0;
            _sheetControlImageView.alpha = 0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 animations:^{
                _compassHeightConstraint.constant = _compassViewSize;
                _compassWidthConstraint.constant = _compassViewSize;
                [_compassView setNeedsUpdateConstraints];
                [_compassView layoutIfNeeded];
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    _headingImageView.alpha = 1;
                }];
            }];
        }];
    }
}

- (CGFloat)_compensatedCompass {
    CGFloat heading = _compassHeading + _compassCompensation;
    if (heading < 0)
        heading += 2 * M_PI;
    if (heading > 2 * M_PI)
        heading -= 2 * M_PI;
    return heading;
}

@end
