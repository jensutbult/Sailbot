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
#import <AudioToolbox/AudioToolbox.h>
#import "SBTMath.h"

@interface SBTViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *boatImageView;
@property (nonatomic, assign) CGFloat windDirection;

@end

@implementation SBTViewController {
    SBTSailbotModel *_sailbot;
    SBTCompassModel *_compass;
    __weak IBOutlet UIImageView *_headingImageView;
    __weak IBOutlet UIImageView *_windImageView;
    __weak IBOutlet UIView *_compassView;
    __weak IBOutlet NSLayoutConstraint *_compassWidthConstraint;
    __weak IBOutlet NSLayoutConstraint *_compassHeightConstraint;
    __weak IBOutlet NSLayoutConstraint *_headingHorizontalConstraint;
    __weak IBOutlet NSLayoutConstraint *_headingVerticalConstraint;
    __weak IBOutlet NSLayoutConstraint *_windHorizontalConstraint;
    __weak IBOutlet NSLayoutConstraint *_windVerticalConstraint;
    __weak IBOutlet UIImageView *_sheetControlImageView;
    __weak IBOutlet NSLayoutConstraint *_sheetControlConstraint;
    __weak IBOutlet UIImageView *_sheetScaleImageView;
    __weak IBOutlet UIImageView *_tillerImageView;
    IBOutletCollection(UIImageView) NSArray *_controlImageViews;
    UIAlertView *_alertView;
    CGFloat _compassViewSize;
    CGFloat _headingOffset;
    CGFloat _heading;
    CGFloat _windDirection;
    CGFloat _windOffset;
    CGFloat _compassHeading;
    CGFloat _compassCompensation;
    CGFloat _enabledControlAlpha;
}

- (void)_updateControlAlpha:(CGFloat)alpha {
    _enabledControlAlpha = alpha;
    for (UIImageView *control in _controlImageViews) {
        if (control.alpha > 0) {
            control.alpha = _enabledControlAlpha;
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _windDirection = -1;
    [self _updateControlAlpha:0.3];
    [[NSNotificationCenter defaultCenter] addObserverForName:SBTSailbotModelStateDidChange object:[SBTSailbotModel shared] queue:nil usingBlock:^(NSNotification *note) {
        [self _sailbotStateDidChange:note];
    }];
    
    _compass = [[SBTCompassModel alloc] initWithHeadingUpdateBlock:^(CGFloat heading) {
        [UIView animateWithDuration:0.3 animations:^{
            _compassHeading = heading;
            _compassView.transform = CGAffineTransformMakeRotation([self _compensatedCompass]);
            [self _rotateHeading:nil];
            [self _updateWindArrow];
        }];
    }];
    _sailbot = [SBTSailbotModel shared];
    __weak SBTViewController *__self = self;
    _sailbot.headingUpdateBlock = ^(CGFloat heading) {
        [UIView animateWithDuration:0.3 animations:^{
            __self.boatImageView.transform = CGAffineTransformMakeRotation(heading);
        }];
    };
    
    _sailbot.windUpdateBlock = ^(CGFloat direction) {
        if (__self.windDirection < 0) {
            __self.windDirection = direction;
            [__self _updateWindArrow];
        }
    };
    
    _headingOffset = _headingHorizontalConstraint.constant;
    _windOffset = _windHorizontalConstraint.constant;
    _compassViewSize = _compassHeightConstraint.constant;
    
    SBTOneFingerRotationGestureRecognizer *rotationGesture = [[SBTOneFingerRotationGestureRecognizer alloc] initWithTarget:self action:@selector(_rotateHeading:)];
    [_headingImageView addGestureRecognizer:rotationGesture];
    
    UIPanGestureRecognizer *steeringControlGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_manualSteering:)];
    steeringControlGesture.maximumNumberOfTouches = 1;
    [_tillerImageView addGestureRecognizer:steeringControlGesture];
    
    UIPanGestureRecognizer *sheetControlGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_manualSheet:)];
    sheetControlGesture.maximumNumberOfTouches = 1;
    [_sheetControlImageView addGestureRecognizer:sheetControlGesture];
    
    SBTOneFingerRotationGestureRecognizer *windDirectionHoldGesture = [[SBTOneFingerRotationGestureRecognizer alloc] initWithTarget:self action:@selector(_rotateWind:)];
    
    [_windImageView addGestureRecognizer:windDirectionHoldGesture];
    
    _boatImageView.layer.anchorPoint = CGPointMake(0.5, 0.5);
}

- (void)_sailbotStateDidChange:(NSNotification *)note {
    if (_alertView) {
        [_alertView dismissWithClickedButtonIndex:0 animated:YES];
        _alertView = nil;
    }
    
    enum SBTSailbotModelState state = [SBTSailbotModel shared].state;
    
    switch (state) {
        case SBTSailbotModelStateConnected: {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [self _updateControlAlpha:1];
            break;
        }
        case SBTSailbotModelStateDisconnected: {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [self _updateControlAlpha:0.3];
            break;
        }
        case SBTSailbotModelStateCalibratingIMU: {
            _alertView = [[UIAlertView alloc] initWithTitle:@"Calibratring IMU" message:@"Don't move boat!" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
            [_alertView show];
            break;
        }
        case SBTSailbotModelStateNoIMU: {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Lost IMU!" message:@"Switch to manual control!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            break;
        }
        case SBTSailbotModelStateWindNotCalibrated: {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Calibrate wind" message:@"Point boat into wind direction" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            break;
        }
        default: {
            break;
        }
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [[SBTSailbotModel shared] sendCalibrateWind:-1];
    
    UIInterfaceOrientation orientation = [self interfaceOrientation];
    if (orientation == UIDeviceOrientationPortrait) {
        [[SBTSailbotModel shared] sendAutomaticControlData];
    } else {
        [[SBTSailbotModel shared] sendManualControlData];
    }
}

- (void)_rotateHeading:(SBTOneFingerRotationGestureRecognizer *)rotationGesture {
    _heading += rotationGesture ? rotationGesture.rotation : 0;
    _heading = fixAnglef(_heading);
    if (rotationGesture)
        [SBTSailbotModel shared].automaticHeading = _heading;
    _headingVerticalConstraint.constant = sinf(_heading + _compassHeading) * _headingOffset;
    _headingHorizontalConstraint.constant = cosf(_heading + _compassHeading) * _headingOffset;
}

- (void)_rotateWind:(SBTOneFingerRotationGestureRecognizer *)rotationGesture {
    _windDirection += rotationGesture ? rotationGesture.rotation : 0;
    _windDirection = fixAnglef(_windDirection);
    if (rotationGesture) {
        [[SBTSailbotModel shared] sendCalibrateWind:_windDirection];
    }
    [self _updateWindArrow];
}

- (void)_updateWindArrow {
    _windVerticalConstraint.constant = sinf(_windDirection + _compassHeading) * _windOffset;
    _windHorizontalConstraint.constant = cosf(_windDirection + _compassHeading) * _windOffset;
    _windImageView.transform = CGAffineTransformMakeRotation(_windDirection + _compassHeading);
}

- (void)_manualSteering:(UIPanGestureRecognizer *)panGesture {
    CGPoint vector;
    vector.x = [panGesture locationInView:self.view].x - _tillerImageView.centerX;
    vector.y = _tillerImageView.centerY - [panGesture locationInView:self.view].y;
    CGFloat angle = atan2(vector.x, vector.y);
    
    // clamp value at 45 degrees
    angle = clampf(angle, M_PI / 4.0, -M_PI / 4.0);
    
    _tillerImageView.transform = CGAffineTransformMakeRotation(angle);
    [SBTSailbotModel shared].manualSteeringControl = angle / (M_PI / 4);
}

- (void)_manualSheet:(UIPanGestureRecognizer *)panGesture {
    CGFloat position = clampf(-([panGesture locationInView:self.view].y - self.view.height/2) / 110.0, 1.0, -1.0);
    [SBTSailbotModel shared].manualSheetControl = position;
    _sheetControlConstraint.constant = position * 110;
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
        [[SBTSailbotModel shared] sendManualControlData];
        [UIView animateWithDuration:0.3 animations:^{
            _headingImageView.alpha = 0;
            _windImageView.alpha = 0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 animations:^{
                _compassHeightConstraint.constant = 250;
                _compassWidthConstraint.constant = 250;
                [_compassView setNeedsUpdateConstraints];
                [_compassView layoutIfNeeded];
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    _tillerImageView.alpha = _enabledControlAlpha;
                    _sheetScaleImageView.alpha = _enabledControlAlpha;
                    _sheetControlImageView.alpha = _enabledControlAlpha;
                }];
            }];
        }];
    } else {
        // Switch to portrait mode (automatic)
        [[SBTSailbotModel shared] sendAutomaticControlData];
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
                    _headingImageView.alpha = _enabledControlAlpha;
                    _windImageView.alpha = _enabledControlAlpha;
                }];
            }];
        }];
    }
}

- (CGFloat)_compensatedCompass {
    CGFloat heading = _compassHeading + _compassCompensation;
    heading = fixAnglef(heading);
    return heading;
}

@end
