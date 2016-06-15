//
//  BWFullScreenSelectionView.m
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "BWFullScreenSelectionView.h"
#import "CGGeometryAdditions.h"

@interface BWCenteredTableViewCell : UITableViewCell

@end

@implementation BWCenteredTableViewCell

-(void)layoutSubviews {
  [super layoutSubviews];
  CGSize size = [self.textLabel sizeThatFits:self.contentView.bounds.size];
  self.textLabel.frame = CGRectFramedCenteredInRect(self.contentView.bounds, size, YES);
}

- (void)prepareForReuse {
  [super prepareForReuse];
  self.backgroundColor = [UIColor clearColor];
  self.contentView.backgroundColor = [UIColor clearColor];
  self.textLabel.textColor = [UIColor whiteColor];
  self.textLabel.font = [UIFont boldSystemFontOfSize:48];
}

@end

@interface BWFullScreenSelectionView () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy, nullable) void (^completion)(BOOL didCancel, NSInteger selected);

@end

@implementation BWFullScreenSelectionView {
  NSArray<NSString *> *_options;
  
  UITableView *_tableView;
}

+ (void)showSelectionInView:(UIView *)view withOptions:(NSArray<NSString *> *)options completion:(void (^)(BOOL didCancel, NSInteger selected))completion {
  BWFullScreenSelectionView *inputView = [[BWFullScreenSelectionView alloc] initWithFrame:view.bounds options:options andCompletion:completion];
  [view addSubview:inputView];
  [inputView _startNewItemFlow];
}

- (instancetype)initWithFrame:(CGRect)frame
                  options:(NSArray<NSString *> *)options
                andCompletion:(void (^)(BOOL didCancel, NSInteger selected))completion {
  self = [super initWithFrame:frame];
  if (self) {
    self.completion = completion;
    NSArray *optionsWithCancel = [options arrayByAddingObjectsFromArray:@[@"Cancel"]];
    _options = [optionsWithCancel copy];
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.alpha = 0.0;
    self.backgroundColor =  [[UIColor lightGrayColor] colorWithAlphaComponent:0.4];
    
    UIButton *cancelFlow = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelFlow.bounds = self.bounds;
    cancelFlow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [cancelFlow addTarget:self action:@selector(_endSelectionCancelledPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:cancelFlow];
    
    _tableView = [[UITableView alloc] initWithFrame:self.bounds];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [_tableView registerClass:[BWCenteredTableViewCell class] forCellReuseIdentifier:@"cell"];
    [self addSubview:_tableView];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGSize tableViewSize = self.bounds.size;
  tableViewSize.height = MIN(_options.count * 60, tableViewSize.height);
  _tableView.frame = CGRectFramedCenteredInRect(self.bounds, tableViewSize, YES);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _options.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  BWCenteredTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  [cell prepareForReuse];
  cell.textLabel.text = _options[indexPath.row];
  return cell;
}

- (void)_startNewItemFlow {;
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 1.0;
  } completion:^(BOOL finished) {

  }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [self _endNewItemFlowCancelled:(indexPath.row == _options.count - 1) withIndex:indexPath.row];
}

- (void)_endNewItemFlowCancelled:(BOOL)cancelled withIndex:(NSInteger)index {
  [UIView animateWithDuration:0.3 animations:^{
    self.alpha = 0;
  } completion:^(BOOL finished) {
    if (self.completion) {
      self.completion(cancelled, index);
    }
    [self removeFromSuperview];
  }];
}

- (void)_endSelectionCancelledPressed:(id)sender {
  [self _endNewItemFlowCancelled:YES withIndex:NSNotFound];
}

@end
