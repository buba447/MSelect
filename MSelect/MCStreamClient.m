//
//  MCStreamClient.m
//  mConnect
//
//  Created by Brandon Withrow on 7/9/14.
//  Copyright (c) 2014 Brandon Withrow. All rights reserved.
//

#import "MCStreamClient.h"
#import "MCStreamRequest.h"
#import "GCDAsyncSocket.h"

static const int BUFFER_SIZE = 4096;

static MCStreamClient *sharedClient = nil;

@interface MCStreamClient () <GCDAsyncSocketDelegate>

@end

@implementation MCStreamClient {
  NSMutableArray *requests_;
  dispatch_queue_t streamQueue_;
  GCDAsyncSocket *socket_;
  NSString *_host;
  int _port;
  BOOL showingNetworkError;
}

- (void)startConnectionWithHost:(NSString *)host andPort:(int)port {
  if (socket_) {
    [socket_ disconnect];
    socket_ = nil;
  }
  requests_ = [NSMutableArray array];
  streamQueue_ = dispatch_queue_create("com.buba447.whatever", DISPATCH_QUEUE_SERIAL);
  socket_ = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:streamQueue_];
  [socket_ connectToHost:host onPort:port error:NULL];
  _host = host;
  _port = port;
  [[MCStreamClient sharedClient] sendPyCommand:@"exec('import json') in globals()" withCompletion:NULL withFailure:NULL];
  [[MCStreamClient sharedClient] sendPyCommand:@"exec('import bw') in globals()" withCompletion:NULL withFailure:NULL];
  [[MCStreamClient sharedClient] sendPyCommand:@"bw.helloWorld()" withCompletion:NULL withFailure:NULL];
}

#pragma mark - Shared Client

+ (MCStreamClient *)sharedClient {
  if (!sharedClient) {
    sharedClient = [[MCStreamClient alloc] init];
  }
  return sharedClient;
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

#pragma mark - Selection Polling


- (void)_startSelectionPolling {
  if (socket_.isConnected) {
    __weak typeof(self) weakSelf = self;
    [[MCStreamClient sharedClient] getJSONFromPyCommand:@"bw.slPoll()"
                                         withCompletion:^(id JSONObject) {
                                           __strong typeof(self) strongSelf = weakSelf;
                                           [strongSelf _handleSelectionPolling:JSONObject];
                                         } withFailure:NULL];
  }
}

- (void)_handleSelectionPolling:(id)response {
  if (response) {
    NSDictionary *userInfo = @{@"data" : response};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMayaSelectionChangedNotification object:self userInfo:userInfo];
  }
  [self performSelector:@selector(_startSelectionPolling) withObject:NULL afterDelay:0.5];
}

#pragma mark - Helper Requests

- (MCStreamRequest *)sendPyCommand:(NSString *)command
       withCompletion:(void (^)(NSString *))completion
          withFailure:(void (^)(void))failure {
  MCStreamRequest *newRequest = [[MCStreamRequest alloc] initWithMessage:command];
  if (completion) {
    newRequest.completionBlock = ^(MCStreamRequest *response) {
      NSString *string = [NSString stringWithUTF8String:[response.responseData bytes]];
      NSLog(@"Command: %@", command);
      NSLog(@"Response: %@", string);
      completion(string);
    };
  }
  if (failure) {
    newRequest.failBlock = ^(MCStreamRequest *response) {
      failure();
    };
  }
  [self addRequestToQueue:newRequest];
  return newRequest;
}

- (void)selectObject:(NSString *)object {
  [self sendPyCommand:[NSString stringWithFormat:@"cmds.select('%@')", object] withCompletion:NULL withFailure:NULL];
}

- (MCStreamRequest *)getJSONFromPyCommand:(NSString *)command
              withCompletion:(void (^)(id JSONObject))completion
                 withFailure:(void (^)(void))failure {
  MCStreamRequest *newRequest = [[MCStreamRequest alloc] initWithMessage:command];
  if (completion) {
    newRequest.completionBlock = ^(MCStreamRequest *response) {
      NSError *error;
      id responseObject = nil;
      NSString *string = [NSString stringWithUTF8String:[response.responseData bytes]];
      if (string) {
        NSLog(@"Command: %@", command);
        NSLog(@"Response: %@", string);
        NSData *metOfficeData = [string dataUsingEncoding:NSUTF8StringEncoding];
        id jsonObject = [NSJSONSerialization JSONObjectWithData:metOfficeData options:kNilOptions error:&error];
        if (!error) {
          responseObject = jsonObject;
        }
      }
      completion(responseObject);
    };
  }
  if (failure) {
    newRequest.failBlock = ^(MCStreamRequest *response) {
      failure();
    };
  }
  [self addRequestToQueue:newRequest];
  return newRequest;
}

#pragma mark - Alert View Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  showingNetworkError = NO;
  if (buttonIndex == 0) {
    return;
  }
  UITextField *textField = [alertView textFieldAtIndex:0];
  NSArray *components = [textField.text componentsSeparatedByString:@":"];
  if (components.count > 1) {
    NSString *host = components[0];
    NSString *port = components[1];
    [self startConnectionWithHost:host andPort:port.intValue];
  }
}

#pragma mark - Private Methods

- (void)notifySucessfulConnection {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  [defaults setObject:_host forKey:@"host"];
  [defaults setObject:@(_port) forKey:@"port"];
  
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter] postNotificationName:kMayaConnectionDidBegin object:nil];
}

- (void)notifyNetworkError {
  [[NSNotificationCenter defaultCenter] postNotificationName:kMayaConnectionDidEnd object:nil];
  
  if (showingNetworkError) {
    return;
  }
  
  showingNetworkError = YES;
  UIAlertView *networkAlert = [[UIAlertView alloc] initWithTitle:@"Connection Error" message:@"Sorry, Maya couldn't be found. Retry?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Connect", nil];
  networkAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
  UITextField *textField = [networkAlert textFieldAtIndex:0];
  textField.text = [NSString stringWithFormat:@"%@:%i", _host, _port];
  
  [networkAlert show];
}

- (void)startQueueIfNecessary {
  if (requests_.count && socket_.isConnected) {
    MCStreamRequest *nextRequest = requests_.firstObject;
    if (nextRequest.status == MCStreamStatusWaiting) {
      nextRequest.status = MCStreamStatusActive;
      NSData *data = [nextRequest.pyCommand dataUsingEncoding:NSUTF8StringEncoding];
      [socket_ writeData:data withTimeout:2 tag:47];
    }
  }
  
  if (socket_.isDisconnected) {
    [self notifyNetworkError];
  }
}

- (void)addRequestToQueue:(MCStreamRequest *)request {
  [requests_ addObject:request];
  request.status = MCStreamStatusWaiting;
  [self startQueueIfNecessary];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
  for (MCStreamRequest *request in requests_) {
    request.status = MCStreamStatusFailed;
    if (request.failBlock) {
      dispatch_async(dispatch_get_main_queue(), ^{
        request.failBlock(request);
      });
    }
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [requests_ removeAllObjects];
    [self notifyNetworkError];
  });
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self notifySucessfulConnection];
    [self startQueueIfNecessary];
  });
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
  [socket_ readDataWithTimeout:5 tag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
  MCStreamRequest *currentRequest = requests_.firstObject;
  [currentRequest.responseData appendData:data];
  currentRequest.status = MCStreamStatusFinished;
  if (currentRequest.completionBlock) {
    dispatch_async(dispatch_get_main_queue(), ^{
      currentRequest.completionBlock(currentRequest);
    });
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    [requests_ removeObject:currentRequest];
    [self startQueueIfNecessary];
  });
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
  NSLog(@"Timeout Write");
  return 0.2;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
  NSLog(@"Timeout read");
  return 0.2;
}

- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
  NSLog(@"Partial Write");
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
  NSLog(@"Partial Read");
}

@end
