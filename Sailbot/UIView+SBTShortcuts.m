//
//  UIView+SBTShortcuts.h.m
//  Sailbot
//
//  Created by Jens Utbult on 2014-05-16.
//  Copyright (c) 2014 Jens Utbult. All rights reserved.
//

#import "UIView+SBTShortcuts.h"

@implementation UIView (SBTShortcuts)

- (CGFloat)left {
	return self.frame.origin.x;
}
- (void)setLeft:(CGFloat)newLeft {
	self.origin = CGPointMake(newLeft, self.origin.y);
}

- (CGFloat)top {
	return self.frame.origin.y;
}
- (void)setTop:(CGFloat)newTop {
	self.origin = CGPointMake(self.origin.x, newTop);
}

- (CGFloat)right {
	return self.frame.origin.x + self.frame.size.width;
}
- (void)setRight:(CGFloat)newRight {
	self.origin = CGPointMake(newRight - self.frame.size.width, self.frame.origin.y);
}

- (CGFloat)bottom {
	return self.frame.origin.y + self.frame.size.height;
}
- (void)setBottom:(CGFloat)newBottom {
	self.origin = CGPointMake(self.frame.origin.x, newBottom - self.frame.size.height);
}

- (CGFloat)width {
	return self.frame.size.width;
}
- (void)setWidth:(CGFloat)newWidth {
	self.size = CGSizeMake(newWidth, self.frame.size.height);
}

- (CGFloat)height {
	return self.frame.size.height;
}
- (void)setHeight:(CGFloat)newHeight {
	self.size = CGSizeMake(self.frame.size.width, newHeight);
}

- (CGFloat)centerX {
	return self.left + (self.width / 2);
}
- (void)setCenterX:(CGFloat)newCenterX {
	self.left = newCenterX - (self.width / 2);
}

- (CGFloat)centerY {
	return self.top + (self.height / 2);
}
- (void)setCenterY:(CGFloat)newCenterY {
	self.top = newCenterY - (self.height / 2);
}

- (CGPoint)origin {
	return self.frame.origin;
}
- (void)setOrigin:(CGPoint)newOrigin {
	self.frame = CGRectMake(newOrigin.x, newOrigin.y, self.size.width, self.size.height);
}

- (CGSize)size {
	return self.frame.size;
}
- (void)setSize:(CGSize)newSize {
	self.frame = CGRectMake(self.origin.x, self.origin.y, newSize.width, newSize.height);
}

@end
