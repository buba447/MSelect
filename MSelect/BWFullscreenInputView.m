//
//  BWFullscreenInputView.m
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "BWFullscreenInputView.h"
#import "CGGeometryAdditions.h"

@interface BWFullscreenInputView () <UITextFieldDelegate>

@property (nonatomic, copy, nullable) void (^completion)(BOOL didCancel, NSString *outputString);

@end

@implementation BWFullscreenInputView {
  UITextField *_newItemTextField;
  UILabel *_titleLabel;
  NSString *_placeholder;
}

+ (void)showInView:(UIView *)view
             title:(NSString *)title
   placeholderText:(NSString *)placeholder
        completion:(void (^)(BOOL didCancel, NSString *outputString))completion {
  BWFullscreenInputView *inputView = [[BWFullscreenInputView alloc] initWithFrame:view.bounds
                                                                            title:title
                                                                      placeHolder:placeholder
                                                                    andCompletion:completion];
  [view addSubview:inputView];
  [inputView _startNewItemFlow];
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
    self.backgroundColor =  [[UIColor lightGrayColor] colorWithAlphaComponent:0.4];
    
    UIButton *cancelFlow = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelFlow.bounds = self.bounds;
    cancelFlow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [cancelFlow addTarget:self action:@selector(_endNewItemFlowCancelledPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:cancelFlow];
    
    _newItemTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    _newItemTextField.placeholder = placeholder;
    _newItemTextField.textColor = [UIColor whiteColor];
    _newItemTextField.clearsOnBeginEditing = YES;
    _newItemTextField.font = [UIFont boldSystemFontOfSize:48];
    [self addSubview:_newItemTextField];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = title;
    _titleLabel.font = [UIFont systemFontOfSize:48];
    _titleLabel.textColor = [UIColor whiteColor];
    [self addSubview:_titleLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldChanged:) name:UITextFieldTextDidChangeNotification object:nil];

  }
  return self;
}

- (void)_startNewItemFlow {;
  _newItemTextField.text = nil;
  _newItemTextField.delegate = self;
  [self _layoutItemTextField];
  
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 1.0;
  } completion:^(BOOL finished) {
    [_newItemTextField becomeFirstResponder];
  }];
}

- (void)_endNewItemFlowCancelled:(BOOL)cancelled {
  _newItemTextField.delegate = nil;
  [_newItemTextField resignFirstResponder];
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 0;
  } completion:^(BOOL finished) {
    if (self.completion) {
      self.completion(cancelled, _newItemTextField.text);
    }
    [self removeFromSuperview];
  }];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [self _layoutItemTextField];
  CGSize labelSize = [_titleLabel sizeThatFits:self.bounds.size];
  _titleLabel.frame = CGRectAttachedTopToRect(_newItemTextField.frame, labelSize, 10, YES);
}

- (void)_layoutItemTextField {
  CGSize fieldSize = [_newItemTextField sizeThatFits:self.bounds.size];
  _newItemTextField.frame = CGRectFramedCenteredInRect(self.bounds, fieldSize, YES);
}

- (void)_endNewItemFlowCancelledPressed:(id)sender {
  [self _endNewItemFlowCancelled:YES];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldChanged:(NSNotificationCenter *)notification {
  _newItemTextField.placeholder = (_newItemTextField.text.length == 0) ? _placeholder : nil;
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
