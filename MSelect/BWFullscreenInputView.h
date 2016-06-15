//
//  BWFullscreenInputView.h
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BWFullscreenInputView : UIView

+ (void)showInView:(UIView *)view
             title:(NSString *)title
   placeholderText:(NSString *)placeholder
        completion:(void (^)(BOOL didCancel, NSString *outputString))completion;

@end
