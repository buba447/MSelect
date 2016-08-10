//
//  MCommand.m
//  MSelect
//
//  Created by Brandon Withrow on 6/14/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "MCommand.h"
#import "MCStreamClient.h"

@implementation MCommand {
  NSString *_pyString;
}

- (void)setCommandType:(MCommandType)commandType {
  _commandType = commandType;
  [self _updatePyString];
}

- (void)setMCommand:(NSString *)mCommand {
  _mCommand = mCommand;
  [self _updatePyString];
}

- (void)setMSelection:(NSString *)mSelection {
  _mSelection = mSelection;
  [self _updatePyString];
}

- (void)_updatePyString {
  NSString *pyString = nil;
  
  switch (_commandType) {
    case MCommandTypeSelection: {
      pyString = [NSString stringWithFormat:@"cmds.select(%@, r=True)", _mSelection];;
    } break;
    case MCommandTypePreviousKeyFrame: {
      pyString = @"cmds.currentTime((cmds.findKeyframe( ts=True, w='previous')))";
    } break;
    case MCommandTypeNextKeyFrame: {
      pyString = @"cmds.currentTime((cmds.findKeyframe( ts=True, w='next')))";
    } break;
    case MCommandTypeNextFrame: {
      pyString = @"cmds.currentTime((cmds.currentTime( query=True ) + 1))";
    } break;
    case MCommandTypePreviousFrame: {
      pyString = @"cmds.currentTime((cmds.currentTime( query=True ) - 1))";
    } break;
    case MCommandTypePlay: {
      pyString = @"cmds.play( forward=True )";
    } break;
    case MCommandTypePause: {
      pyString = @"cmds.play( state=False )";
    } break;
    case MCommandTypeKeySelected: {
      pyString = @"cmds.setKeyframe()";
    } break;
    case MCommandTypeKeySelection: {
      pyString =[NSString stringWithFormat:@"cmds.setKeyframe(%@)", _mSelection];
    } break;
    case MCommandTypeForwardTen: {
      pyString = @"cmds.currentTime((cmds.currentTime( query=True ) + 10))";
    } break;
    case MCommandTypeBackTen: {
      pyString = @"cmds.currentTime((cmds.currentTime( query=True ) + 10))";
    } break;
    case MCommandTypeCustomCommand: {
      if (_mSelection.length) {
        pyString = [self.mCommand stringByReplacingOccurrencesOfString:@"@" withString:_mSelection];
      } else {
        pyString = self.mCommand;
      }
    } break;
    default:
      break;
  }
  
  _pyString = pyString;
}

- (void)loadSelectionsFromMayaIfNecesarry:(void (^)(void))callBack {
  [[MCStreamClient sharedClient] sendPyCommand:@"cmds.ls(sl=True)" withCompletion:^(NSString *returned) {
    NSString *stripped = [returned stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    self.mSelection = stripped;
    if (callBack) {
      callBack();
    }
  } withFailure:^{
    
  }];
}

- (void)sendCommandToMaya {
  if (_pyString.length) {
    [[MCStreamClient sharedClient] sendPyCommand:_pyString withCompletion:^(NSString *response) {
      
    } withFailure:^{
      
    }];
  }
}

+ (NSArray *)commandTitles {
  return @[@"Selection",
           @"Key Object",
           @"Key Selected",
           @"->",
           @"<-",
           @"Play",
           @"Pause",
           @">|",
           @"|<",
           @"Custom Command",
           @"(10)->",
           @"<-(10)"];
}

+ (NSString *)titleForCommand:(MCommandType)command {
  return [MCommand commandTitles][command];
}

@end
