//
//  MCstreamRequest.h
//  mConnect
//
//  Created by Brandon Withrow on 7/9/14.
//  Copyright (c) 2014 Brandon Withrow. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
  MCStreamStatusNone,
  MCStreamStatusActive,
  MCStreamStatusFinished,
  MCStreamStatusFailed,
  MCStreamStatusWaiting,
  MCStreamRequestCancelled
} MCStreamStatus;

@class MCStreamRequest;
typedef void(^MCStreamRequestResponseBlock)(MCStreamRequest *response);

@interface MCStreamRequest : NSObject

@property (nonatomic, readonly) NSMutableData *responseData;
@property (nonatomic, readonly) NSString *pyCommand;
@property (nonatomic, copy) MCStreamRequestResponseBlock completionBlock;
@property (nonatomic, copy) MCStreamRequestResponseBlock failBlock;
@property (nonatomic, assign) MCStreamStatus status;

- (id)initWithMessage:(NSString *)message;

@end
