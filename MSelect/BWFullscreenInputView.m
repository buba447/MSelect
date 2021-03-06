//
//  BWFullscreenInputView.m
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "BWFullscreenInputView.h"
#import "CGGeometryAdditions.h"
#import "UIColor+mcAdditions.h"

@interface BWFullscreenInputView () <UITextFieldDelegate>

@property (nonatomic, copy, nullable) void (^completion)(BOOL didCancel, NSString *outputString);

@end

@implementation BWFullscreenInputView {
  UILabel *_titleLabel;
  NSString *_placeholder;
}

+ (BWFullscreenInputView *)showInView:(UIView *)view
             title:(NSString *)title
   placeholderText:(NSString *)placeholder
        completion:(void (^)(BOOL didCancel, NSString *outputString))completion {
  BWFullscreenInputView *inputView = [[BWFullscreenInputView alloc] initWithFrame:view.bounds
                                                                            title:title
                                                                      placeHolder:placeholder
                                                                    andCompletion:completion];
  [view addSubview:inputView];
  [inputView _startNewItemFlow];
  return inputView;
}

- (instancetype)initWithFrame:(CGRect)frame
                        title:(NSString *)title
                  placeHolder:(NSString *)placeholder
                andCompletion:(void (^)(BOOL didCancel, NSString *outputString))completion {
  self = [super initWithFrame:frame];
  if (self) {
    _placeholder = placeholder;
    self.completion = completion;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.alpha = 0.0;
    self.backgroundColor =  [[UIColor mayaBackgroundColor] colorWithAlphaComponent:0.7];
    
    UIButton *cancelFlow = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelFlow.bounds = self.bounds;
    cancelFlow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [cancelFlow addTarget:self action:@selector(_endNewItemFlowCancelledPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:cancelFlow];
    
    _textEntryField = [[UITextField alloc] initWithFrame:CGRectZero];
    _textEntryField.placeholder = placeholder;
    _textEntryField.textColor = [UIColor whiteColor];
    _textEntryField.clearsOnBeginEditing = YES;
    _textEntryField.font = [UIFont boldSystemFontOfSize:48];
    [self addSubview:_textEntryField];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = title;
    _titleLabel.font = [UIFont systemFontOfSize:22];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.numberOfLines = 0;
    [self addSubview:_titleLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldChanged:) name:UITextFieldTextDidChangeNotification object:nil];

  }
  return self;
}

- (void)_startNewItemFlow {;
  _textEntryField.text = nil;
  _textEntryField.delegate = self;
  [self _layoutItemTextField];
  
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 1.0;
  } completion:^(BOOL finished) {
    [_textEntryField becomeFirstResponder];
  }];
}

- (void)_endNewItemFlowCancelled:(BOOL)cancelled {
  _textEntryField.delegate = nil;
  [_textEntryField resignFirstResponder];
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 0;
  } completion:^(BOOL finished) {
    if (self.completion) {
      self.completion(cancelled, _textEntryField.text);
    }
    [self removeFromSuperview];
  }];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [self _layoutItemTextField];
  CGSize labelConstraint = self.bounds.size;
  labelConstraint.width = floorf(labelConstraint.width * 0.7);
  CGSize labelSize = [_titleLabel sizeThatFits:labelConstraint];
  _titleLabel.frame = CGRectAttachedBottomToRect(_textEntryField.frame, labelSize, 10, YES);
}

- (void)_layoutItemTextField {
  CGSize fieldSize = [_textEntryField sizeThatFits:self.bounds.size];
  _textEntryField.frame = CGRectFramedCenteredInRect(self.bounds, fieldSize, YES);
}

- (void)_endNewItemFlowCancelledPressed:(id)sender {
  [self _endNewItemFlowCancelled:YES];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldChanged:(NSNotificationCenter *)notification {
  _textEntryField.placeholder = (_textEntryField.text.length == 0) ? _placeholder : nil;
  [self _layoutItemTextField];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  [self _endNewItemFlowCancelled:(textField.text.length == 0)];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return NO;
}

@end
