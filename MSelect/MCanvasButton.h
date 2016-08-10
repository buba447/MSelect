//
//  MCanvasButton.h
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MCommand.h"

@interface MCanvasButton : UIButton

@property (nonatomic, strong) MCommand *command;

@property (nonatomic, strong) UIColor *buttonBackgroundColor;
@property (nonatomic, strong) UIColor *buttonHighlightColor;

- (void)updateTitle;

@end
