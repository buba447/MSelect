//
//  MCstreamRequest.m
//  mConnect
//
//  Created by Brandon Withrow on 7/9/14.
//  Copyright (c) 2014 Brandon Withrow. All rights reserved.
//

#import "MCStreamRequest.h"

@implementation MCStreamRequest {
  NSMutableData *_responseData;
}

- (id)initWithMessage:(NSString *)message {
  self = [super init];
  if (self) {
    _responseData = [NSMutableData data];
    _status = MCStreamStatusNone;
    _pyCommand = message;
  }
  return self;
}

- (void)dealloc {
  NSLog(@"Request Dealloc");
}

@end
