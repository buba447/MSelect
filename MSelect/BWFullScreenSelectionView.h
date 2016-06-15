//
//  BWFullScreenSelectionView.h
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BWFullScreenSelectionView : UIView

+ (void)showSelectionInView:(UIView *)view withOptions:(NSArray<NSString *> *)options completion:(void (^)(BOOL didCancel, NSInteger selected))completion;

@end
