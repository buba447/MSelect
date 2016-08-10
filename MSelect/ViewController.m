//
//  ViewController.m
//  MSelect
//
//  Created by Brandon Withrow on 6/11/16.
//  Copyright © 2016 Brandon Withrow. All rights reserved.
//

#import "ViewController.h"
#import "MCanvasButton.h"
#import "UIColor+mcAdditions.h"
#import "BWFullscreenInputView.h"
#import "MCStreamClient.h"
#import "CGGeometryAdditions.h"
#import "BWFullScreenSelectionView.h"

@interface ViewController ()

@end

@implementation ViewController {
  UILongPressGestureRecognizer *_longPress;
  UIPanGestureRecognizer *_panGesture;
  
  NSMutableArray *_canvasButtons;
  
  UIView *_canvasContainer;
  
  MCanvasButton *_loadButton;
  MCanvasButton *_newButton;
  MCanvasButton *_rearrangeButton;
  
  MCanvasButton *_panningButton;
  
  NSString *_currentLoadedScene;
  NSArray *_availableScenes;
  BOOL _lockedScene;
  float _x;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mayaDidConnect:) name:kMayaConnectionDidBegin object:nil];
  _x = 0;
  _canvasButtons = [NSMutableArray array];
  self.view.backgroundColor = [UIColor mayaBackgroundColor];
  
  _canvasContainer = [[UIView alloc] initWithFrame:self.view.bounds];
  _canvasContainer.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.view addSubview:_canvasContainer];

  _loadButton = [[MCanvasButton alloc] initWithFrame:CGRectZero];
  [_loadButton setTitle:@"Load Scene" forState:UIControlStateNormal];
  CGSize size = [_loadButton sizeThatFits:self.view.bounds.size];
  size.width += 40;
  size.height += 22;
  [_loadButton addTarget:self action:@selector(_openScenePressed:) forControlEvents:UIControlEventTouchUpInside];
  _loadButton.frame = CGRectFramedBottomRightInRect(self.view.bounds, size, 20, 20, YES);
  [_canvasContainer addSubview:_loadButton];
  
  _newButton = [[MCanvasButton alloc] initWithFrame:CGRectZero];
  [_newButton setTitle:@"New Scene" forState:UIControlStateNormal];
  size = [_newButton sizeThatFits:self.view.bounds.size];
  size.width += 40;
  size.height += 22;
  [_newButton addTarget:self action:@selector(_newScenePressed:) forControlEvents:UIControlEventTouchUpInside];
  _newButton.frame = CGRectAttachedLeftToRect(_loadButton.frame, size, 10, YES);
  [_canvasContainer addSubview:_newButton];
  
  _rearrangeButton = [[MCanvasButton alloc] initWithFrame:CGRectZero];
  [_rearrangeButton setTitle:@"Rearrange" forState:UIControlStateNormal];
  size = [_rearrangeButton sizeThatFits:self.view.bounds.size];
  size.width += 40;
  size.height += 22;
  [_rearrangeButton addTarget:self action:@selector(_rearrangeScenePressed:) forControlEvents:UIControlEventTouchUpInside];
  _rearrangeButton.frame = CGRectAttachedLeftToRect(_newButton.frame, size, 10, YES);
  [_canvasContainer addSubview:_rearrangeButton];
  
  _longPress =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
  _longPress.minimumPressDuration = 0.4;
  [_canvasContainer addGestureRecognizer:_longPress];
  
  _panGesture =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
  _panGesture.enabled = NO;
  [_canvasContainer addGestureRecognizer:_panGesture];
}

#pragma mark -- Gestures

- (void)handleLongPress:(UILongPressGestureRecognizer *)press {
  CGPoint loc = [press locationInView:_canvasContainer];
  if (press.state == UIGestureRecognizerStateBegan) {
    UIView *testView = [self.view hitTest:loc withEvent:nil];
    if (testView == _newButton || testView == _loadButton || testView == _rearrangeButton) {
      return;
    }
    if ([_canvasButtons containsObject:testView]) {
      [self _showButtonEditChoicesForButton:(MCanvasButton *)testView];
    } else {
      loc.x = round(loc.x / 10) * 10;
      loc.y = round(loc.y / 10) * 10;
      [self _startNewButtonFlowAtLocation:loc];
    }
  }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)panGesture {
  if (panGesture.state == UIGestureRecognizerStateBegan) {
    CGPoint loc = [panGesture locationInView:_canvasContainer];
    for (MCanvasButton *button in _canvasButtons) {
      if (CGRectContainsPoint(button.frame, loc)) {
        _panningButton = button;
        break;
      }
    }
    if (!_panningButton) {
      [self _endRearrangingScene];
    }
  }
  
  _panningButton.center = [panGesture locationInView:self.view];
  
  if (panGesture.state == UIGestureRecognizerStateEnded) {
    [self _moveButton:_panningButton toLocation:_panningButton.center];
    _panningButton = nil;
  }
}

#pragma mark -- New Button Flow

- (void)_startNewButtonFlowAtLocation:(CGPoint)location {
  if (_lockedScene) {
    return;
  }
  MCommand *command = [[MCommand alloc] init];
  
  MCanvasButton *button = [self newButtonWithCommand:command];
  button.center = location;
  
  [self _showEditButtonType:button withCompletion:^(MCanvasButton *editedButton) {
    if (button.command.commandType == MCommandTypeCustomCommand ||
        button.command.commandType == MCommandTypeSelection) {
      [self _showEditButtonTitle:button withCompletion:^(MCanvasButton *editedButton) {
        [self _loadSelectionsForButton:button withCompletion:^(MCanvasButton *editedButton) {
          [self _saveToCreatedScene];
        }];
      }];
    } else {
      [self _loadSelectionsForButton:button withCompletion:^(MCanvasButton *editedButton) {
        [self _saveToCreatedScene];
      }];
    }
  }];
  
}

- (MCanvasButton *)newButtonWithCommand:(MCommand *)command {
  MCanvasButton *newButton = [[MCanvasButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
  newButton.command = command;
  [_canvasButtons addObject:newButton];
  [_canvasContainer addSubview:newButton];
  [newButton addTarget:self action:@selector(_canvasButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
  return newButton;
}

#pragma mark -- Button Functions

- (void)_layoutButton:(MCanvasButton *)button atCenter:(CGPoint)center {
  CGSize size = [button sizeThatFits:self.view.bounds.size];
  size.width += 40;
  size.height += 22;
  button.bounds = CGRectMake(0, 0, size.width, size.height);
  center.x = round(center.x / 10) * 10;
  center.y = round(center.y / 10) * 10;
  button.center = center;
}

#pragma mark -- Scene Flows

- (void)_showOpenSceneSelection {
  if (_availableScenes.count == 0) {
    [self _newScenePressed:nil];
    return;
  }
  NSMutableArray *options = [NSMutableArray array];
  for (NSString *string in _availableScenes) {
    NSArray *split = [string componentsSeparatedByString:@"mselscene"];
    [options addObject:split.lastObject];
  }
  
  [BWFullScreenSelectionView showSelectionInView:self.view withOptions:options completion:^(BOOL didCancel, NSInteger selected) {
    if (!didCancel && selected != NSNotFound) {
      NSString *scene = _availableScenes[selected];
      [self _loadSceneDataFromMaya:scene];
    }
  }];
}

- (void)_showNewSceneNameDialog {
  [BWFullscreenInputView showInView:self.view
                              title:nil
                    placeholderText:@"New Scene"
                         completion:^(BOOL didCancel, NSString *outputString) {
                           if (!didCancel) {
                             NSCharacterSet *charactersToRemove = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                             NSString *strippedReplacement = [[outputString componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@""];
                             [self _createSceneNamed:strippedReplacement];
                           }
                         }];
}

#pragma mark -- Scene Management

- (void)_startRearrangingScene {
  if (_panGesture.enabled) {
    [self _endRearrangingScene];
    return;
  }
  for (MCanvasButton *button in _canvasButtons) {
    button.enabled = NO;
  }
  _rearrangeButton.buttonBackgroundColor = [UIColor mayaActiveColor];
  _longPress.enabled = NO;
  _panGesture.enabled = YES;
}

- (void)_endRearrangingScene {
  for (MCanvasButton *button in _canvasButtons) {
    button.enabled = YES;
  }
  _rearrangeButton.buttonBackgroundColor = [UIColor mayaSelectionColor];
  _longPress.enabled = YES;
  _panGesture.enabled = NO;
}

- (void)_clearScene {
  for (MCanvasButton *button in _canvasButtons) {
    [button removeFromSuperview];
  }
  _lockedScene = NO;
  [_canvasButtons removeAllObjects];
  _currentLoadedScene = nil;
}

#pragma mark -- Action Responders

- (void)_canvasButtonPressed:(MCanvasButton *)canvasButton {
  [canvasButton.command sendCommandToMaya];
}

- (void)_openScenePressed:(id)sender {
  [self _getSavedSceneNamesFromMaya];
}

- (void)_newScenePressed:(id)sender {
  [self _showNewSceneNameDialog];
}

- (void)_rearrangeScenePressed:(id)sender {
  [self _startRearrangingScene];
}

- (void)_mayaDidConnect:(NSNotification *)notification {
  [self _getSavedSceneNamesFromMaya];
  [self _sendMoveLoop];
}

- (void)_sendMoveLoop {
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.xform(t=(%f, 0, 0))", _x];
  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    [self performSelector:@selector(_sendMoveLoop) withObject:nil afterDelay:0.041];
  } withFailure:^{
    
  }];
  
  
  _x += 0.03;
  if (_x > 10) {
    _x = 0;
  }
}

#pragma mark -- Button Editing Flows

- (void)_showButtonEditChoicesForButton:(MCanvasButton *)button {
  if (_lockedScene) {
    return;
  }
  [BWFullScreenSelectionView showSelectionInView:self.view
                                     withOptions:@[@"Edit Title", @"Change Type", @"Reload Selections", @"Delete"]
                                      completion:^(BOOL didCancel, NSInteger selected) {
                                        if (!didCancel && selected != NSNotFound) {
                                          if (selected == 0) {
                                            [self _showEditButtonTitle:button withCompletion:^(MCanvasButton *editedButton) {
                                              [self _saveToCreatedScene];
                                            }];
                                          }
                                          if (selected == 1) {
                                            [self _showEditButtonType:button withCompletion:^(MCanvasButton *editedButton) {
                                              [self _saveToCreatedScene];
                                            }];
                                          }
                                          if (selected == 2) {
                                            [self _loadSelectionsForButton:button withCompletion:^(MCanvasButton *editedButton) {
                                              [self _saveToCreatedScene];
                                            }];
                                          }
                                          if (selected == 3) {
                                            [self _deleteButton:button];
                                          }
                                        }
                                      }];
}

- (void)_showEditButtonType:(MCanvasButton *)button withCompletion:(void (^)(MCanvasButton *editedButton))callBack {
  NSArray *commandTypes = [MCommand commandTitles];
  [BWFullScreenSelectionView showSelectionInView:self.view
                                     withOptions:commandTypes
                                      completion:^(BOOL didCancel, NSInteger selected) {
                                        if (!didCancel && selected < commandTypes.count) {
                                          button.command.commandType = selected;
                                          if (button.command.commandType != MCommandTypeSelection) {
                                            button.command.name = commandTypes[selected];
                                            [button updateTitle];
                                            [self _layoutButton:button atCenter:button.center];
                                          }
                                          if (button.command.commandType == MCommandTypeCustomCommand) {
                                            [self _showEditCustomCommand:button withCompletion:callBack];
                                          } else if (callBack) {
                                            callBack(button);
                                          }
                                        }
                                      }];
}

- (void)_showEditButtonTitle:(MCanvasButton *)button withCompletion:(void (^)(MCanvasButton *editedButton))callBack {
  [BWFullscreenInputView showInView:self.view title:nil placeholderText:@"Button Name" completion:^(BOOL didCancel, NSString *outputString) {
    if (!didCancel) {
      button.command.name = outputString;
      [button updateTitle];
      [self _layoutButton:button atCenter:button.center];
      if (callBack) {
        callBack(button);
      }
    }
  }];
}

- (void)_showEditCustomCommand:(MCanvasButton *)button withCompletion:(void (^)(MCanvasButton *editedButton))callBack {
  BWFullscreenInputView *inputView = [BWFullscreenInputView showInView:self.view title:@"Enter a python command. Use 'cmds.' to access Maya commands." placeholderText:@"Python Command" completion:^(BOOL didCancel, NSString *outputString) {
    if (!didCancel) {
      button.command.mCommand = outputString;
      if (callBack) {
        callBack(button);
      }
    }
  }];
  inputView.textEntryField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  inputView.textEntryField.autocorrectionType = UITextAutocorrectionTypeNo;
}

- (void)_loadSelectionsForButton:(MCanvasButton *)button withCompletion:(void (^)(MCanvasButton *editedButton))callBack {
  [button.command loadSelectionsFromMayaIfNecesarry:^{
    if (callBack) {
      callBack(button);
    }
  }];
}

- (void)_deleteButton:(MCanvasButton *)button {
  [button removeFromSuperview];
  [_canvasButtons removeObject:button];
  [self _saveToCreatedScene];
}

- (void)_moveButton:(MCanvasButton *)button toLocation:(CGPoint)location {
  [self _layoutButton:button atCenter:location];
  [self _saveToCreatedScene];
}

#pragma mark - Maya Saving and Loading.

- (void)_getSavedSceneNamesFromMaya {
  NSString *pyCommand = @"json.dumps(cmds.ls('mselscene*', r=True))";
  [[MCStreamClient sharedClient] getJSONFromPyCommand:pyCommand withCompletion:^(id JSONObject) {
    if ([JSONObject isKindOfClass:[NSArray class]]) {
      _availableScenes = [(NSArray *)JSONObject copy];
      [self _showOpenSceneSelection];
    }
  } withFailure:^{
    
  }];
}

- (void)_loadSceneDataFromMaya:(NSString *)fullPath {
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.getAttr('%@.sls')", fullPath];
  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    [self _unwrapScene:fullPath withJSON:response];
  } withFailure:^{
    
  }];
}

- (void)_createSceneNamed:(NSString *)sceneName {
  [self _clearScene];
  NSString *fullPath = [NSString stringWithFormat:@"mselscene%@", sceneName];
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.namespace(set=':');cmds.scriptNode(n='%@');cmds.addAttr('%@', longName='sls', dataType='string');", fullPath, fullPath];
  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    _currentLoadedScene = fullPath;
    [self _saveToCreatedScene];
  } withFailure:^{
    
  }];
}

- (void)_saveToCreatedScene {
  if (!_canvasButtons.count) {
    return;
  }
  NSMutableArray *jsonRepresentation = [NSMutableArray array];
  
  for (MCanvasButton *button in _canvasButtons) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    dict[@"x"] = @(button.center.x);
    dict[@"y"] = @(button.center.y);
    
    if (button.command) {
      dict[@"t"] = @(button.command.commandType);
    }
    
    if (button.command.name) {
      dict[@"n"] = button.command.name;
    }
    
    if (button.command.mSelection) {
      dict[@"s"] = button.command.mSelection;
    }
    
    if (button.command.mCommand) {
      dict[@"c"] = button.command.mCommand;
    }
    
    if (button.command.mSelection) {
      dict[@"s"] = button.command.mSelection;
    }
    
    [jsonRepresentation addObject:dict];
  }
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonRepresentation options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  
  [self _saveToSceneNamed:_currentLoadedScene jsonString:jsonString];
}

- (void)_saveToSceneNamed:(NSString *)sceneName jsonString:(NSString *)json {
  
  NSString *escaped = [json stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  NSString *attr = [NSString stringWithFormat:@"%@.sls", sceneName];
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.setAttr('%@', edit=True, lock=False); cmds.setAttr('%@', \"%@\", type='string'); cmds.setAttr('%@', edit=True, lock=True)", attr,attr,escaped,attr];
  
  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    
  } withFailure:^{
    
  }];
}

- (void)_unwrapScene:(NSString *)sceneName withJSON:(NSString *)json {
  [self _clearScene];
  _currentLoadedScene = sceneName;
  
  NSArray *nameSpaces = [sceneName componentsSeparatedByString:@"mselscene"];
  NSString *namespaceString;
  if (nameSpaces.count > 1 &&
      [nameSpaces[0] length] > 1) {
    _lockedScene = YES;
    namespaceString = nameSpaces.firstObject;
  } else {
    _lockedScene = NO;
  }
  _rearrangeButton.enabled = !_lockedScene;
  
  NSData *metOfficeData = [json dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:metOfficeData options:kNilOptions error:&error];
  if ([jsonObject isKindOfClass:[NSArray class]]) {
    NSArray *buttons = (NSArray *)jsonObject;
    for (id obj in buttons) {
      if (![obj isKindOfClass:[NSDictionary class]]) {
        continue;
      }
      NSDictionary *dictionary = (NSDictionary *)obj;
      MCommand *command = [[MCommand alloc] init];
      command.name = dictionary[@"n"];
      command.mCommand = dictionary[@"c"];
      NSString *selections = dictionary[@"s"];
      if (namespaceString.length) {
        NSString *replacementString = [NSString stringWithFormat:@"u'%@", namespaceString];
        selections = [selections stringByReplacingOccurrencesOfString:@"u'" withString:replacementString];
      }
      command.mSelection = selections;
      command.commandType = [dictionary[@"t"] integerValue];
      
      MCanvasButton *button = [self newButtonWithCommand:command];
      CGPoint center = button.center;
      if (dictionary[@"x"] && dictionary[@"y"]) {
        center = CGPointMake([dictionary[@"x"] floatValue], [dictionary[@"y"] floatValue]);
      }
      [button updateTitle];
      [self _layoutButton:button atCenter:center];
    }
  }
  if (_lockedScene) {
    [[[UIAlertView alloc] initWithTitle:@"Scene is locked" message:@"This scene is loaded from a referenced maya file.\nEditing for this scene is disabled. To edit this scene please open the referenced file in Maya." delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
  }
}

@end
