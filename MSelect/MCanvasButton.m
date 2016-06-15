//
//  MCanvasButton.m
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "MCanvasButton.h"
#import "UIColor+mcAdditions.h"

@implementation MCanvasButton

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.layer.cornerRadius = 5;
    self.backgroundColor = [UIColor mayaSelectionColor];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor mayaSelectionColor] forState:UIControlStateHighlighted];
    _buttonBackgroundColor = [UIColor mayaSelectionColor];
    _buttonHighlightColor = [UIColor mayaActiveColor];
  }
  return self;
}

- (void)_updateBackgroundColor {
  self.backgroundColor = self.enabled ? (self.highlighted ? self.buttonHighlightColor : self.buttonBackgroundColor) : [UIColor lightGrayColor];
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  [self _updateBackgroundColor];
}

- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  [self _updateBackgroundColor];
}

- (void)setButtonBackgroundColor:(UIColor *)buttonBackgroundColor {
  _buttonBackgroundColor = buttonBackgroundColor;
  [self _updateBackgroundColor];
}

@end
