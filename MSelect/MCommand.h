//
//  MCommand.h
//  MSelect
//
//  Created by Brandon Withrow on 6/14/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
  MCommandTypeSelection,
  MCommandTypeKeySelection,
  MCommandTypeKeySelected,
  MCommandTypeNextFrame,
  MCommandTypePreviousFrame,
  MCommandTypePlay,
  MCommandTypePause,
  MCommandTypeNextKeyFrame,
  MCommandTypePreviousKeyFrame,
  MCommandTypeCustomCommand,
  MCommandTypeForwardTen,
  MCommandTypeBackTen
} MCommandType;

@interface MCommand : NSObject

@property (nonatomic, strong) NSString *name;

@property (nonatomic, assign) MCommandType commandType;
@property (nonatomic, strong) NSString *mCommand;
@property (nonatomic, strong) NSString *mSelection;

- (void)loadSelectionsFromMayaIfNecesarry:(void (^)(void))callBack;
- (void)sendCommandToMaya;

+ (NSString *)titleForCommand:(MCommandType)command;
+ (NSArray *)commandTitles;
@end
