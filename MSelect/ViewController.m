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
  NSMutableArray *_selections;
  CGPoint _newItemCenterPoint;
  
  UIView *_canvasContainer;
  
  MCanvasButton *_loadButton;
  MCanvasButton *_newButton;
  MCanvasButton *_rearrangeButton;
  
  MCanvasButton *_panningButton;
  
  NSString *_currentLoadedScene;
  NSArray *_availableScenes;
  BOOL _lockedScene;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mayaDidConnect:) name:kMayaConnectionDidBegin object:nil];
  
  _canvasButtons = [NSMutableArray array];
  _selections = [NSMutableArray array];
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)press {
  if (press.state == UIGestureRecognizerStateBegan) {
    _newItemCenterPoint = [press locationInView:self.view];
    
    UIView *testView = [self.view hitTest:_newItemCenterPoint withEvent:nil];
    if ([_canvasButtons containsObject:testView]) {
      [self _showButtonEditChoicesForButton:(MCanvasButton *)testView];
    } else {
      [self _startNewButtonFlow];
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

- (void)_startNewButtonFlow {
  if (_lockedScene) {
    return;
  }
  [BWFullscreenInputView showInView:self.view
                              title:nil
                    placeholderText:@"New Button"
                         completion:^(BOOL didCancel, NSString *outputString) {
    if (!didCancel) {
      [self _getSelectedMayaAttributesForNewButtonNamed:outputString];
    }
  }];
}

- (void)_getSelectedMayaAttributesForNewButtonNamed:(NSString *)name {
  [[MCStreamClient sharedClient] sendPyCommand:@"cmds.ls(sl=True)" withCompletion:^(NSString *returned) {
    NSString *stripped = [returned stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    [self _addNewSelectionButtonWithItems:stripped andName:name atLocation:_newItemCenterPoint];
  } withFailure:^{
    
  }];
}

- (void)_addNewSelectionButtonWithItems:(NSString *)items andName:(NSString *)name atLocation:(CGPoint)center {
  MCanvasButton *newButton = [[MCanvasButton alloc] initWithFrame:CGRectZero];
  [newButton setTitle:name forState:UIControlStateNormal];
  [self _layoutButton:newButton atCenter:center];
  [_selections addObject:items];
  [_canvasButtons addObject:newButton];
  [_canvasContainer addSubview:newButton];
  [newButton addTarget:self action:@selector(_canvasButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
  [self _saveToCreatedScene];
}

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

- (void)_layoutButton:(MCanvasButton *)button atCenter:(CGPoint)center {
  CGSize size = [button sizeThatFits:self.view.bounds.size];
  size.width += 40;
  size.height += 22;
  button.bounds = CGRectMake(0, 0, size.width, size.height);
  center.x = round(center.x / 10) * 10;
  center.y = round(center.y / 10) * 10;
  button.center = center;
}

#pragma mark -- Action Responders

- (void)_canvasButtonPressed:(UIButton *)canvasButton {
  NSInteger idx = [_canvasButtons indexOfObject:canvasButton];
  if (idx != NSNotFound) {
    NSString *selection = _selections[idx];
    NSString *pyCommand = [NSString stringWithFormat:@"cmds.select(%@, r=True)", selection];
    [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
      
    } withFailure:^{
      
    }];
  }
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
  [_selections removeAllObjects];
  _currentLoadedScene = nil;
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

- (void)_mayaDidConnect:(NSNotification *)notification {
  [self _getSavedSceneNamesFromMaya];
}

#pragma mark -- Button Editing

- (void)_showButtonEditChoicesForButton:(MCanvasButton *)button {
  if (_lockedScene) {
    return;
  }
  [BWFullScreenSelectionView showSelectionInView:self.view
                                     withOptions:@[@"Edit Title", @"Reload Selections", @"Delete"]
                                      completion:^(BOOL didCancel, NSInteger selected) {
                                        if (!didCancel && selected != NSNotFound) {
                                          if (selected == 0) {
                                            [self _editButtonTitle:button];
                                          }
                                          if (selected == 1) {
                                            [self _reloadSelectionsForButton:button];
                                          }
                                          if (selected == 2) {
                                            [self _deleteButton:button];
                                          }
                                        }
                                      }];
}

- (void)_editButtonTitle:(MCanvasButton *)button {
  [BWFullscreenInputView showInView:self.view title:nil placeholderText:@"Button Name" completion:^(BOOL didCancel, NSString *outputString) {
    if (!didCancel) {
      [button setTitle:outputString forState:UIControlStateNormal];
      [self _layoutButton:button atCenter:button.center];
      [self _saveToCreatedScene];
    }
  }];
}

- (void)_reloadSelectionsForButton:(MCanvasButton *)button {
  NSInteger idx = [_canvasButtons indexOfObject:button];
  if (idx == NSNotFound) {
    return;
  }
  [[MCStreamClient sharedClient] sendPyCommand:@"cmds.ls(sl=True)" withCompletion:^(NSString *returned) {
    NSString *stripped = [returned stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    _selections[idx] = stripped;
    [self _saveToCreatedScene];
  } withFailure:^{
    
  }];
}

- (void)_deleteButton:(MCanvasButton *)button {
  NSInteger idx = [_canvasButtons indexOfObject:button];
  if (idx == NSNotFound) {
    return;
  }
  [button removeFromSuperview];
  [_canvasButtons removeObject:button];
  [_selections removeObjectAtIndex:idx];
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
  // This adds the mselscene namespace
  [self _clearScene];
  NSString *fullPath = [NSString stringWithFormat:@"mselscene%@", sceneName];
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.namespace(set=':');cmds.scriptNode(n='%@');cmds.addAttr('%@', longName='sls', dataType='string');", fullPath, fullPath];
  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    _currentLoadedScene = fullPath;
    [self _saveToCreatedScene];
  } withFailure:^{
    
  }];
}

- (void)_saveToSceneNamed:(NSString *)sceneName jsonString:(NSString *)json {
  
  NSString *escaped = [json stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  NSString *attr = [NSString stringWithFormat:@"%@.sls", sceneName];
  NSString *pyCommand = [NSString stringWithFormat:@"cmds.setAttr('%@', edit=True, lock=False); cmds.setAttr('%@', \"%@\", type='string'); cmds.setAttr('%@', edit=True, lock=True)", attr,attr,escaped,attr];

  [[MCStreamClient sharedClient] sendPyCommand:pyCommand withCompletion:^(NSString *response) {
    
  } withFailure:^{
    
  }];
}

- (void)_saveToCreatedScene {
  if (!_canvasButtons.count) {
    return;
  }
  NSMutableArray *jsonRepresentation = [NSMutableArray array];
  
  for (NSInteger idx = 0; idx < _canvasButtons.count; idx ++) {
    MCanvasButton *button = _canvasButtons[idx];
    NSString *selection = _selections[idx];
    NSString *stripped = [selection stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSDictionary *dictionary = @{@"x" : @(button.center.x),
                                 @"y" : @(button.center.y),
                                 @"s" : stripped,
                                 @"n" : button.titleLabel.text};
    [jsonRepresentation addObject:dictionary];
  }
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonRepresentation options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  
  [self _saveToSceneNamed:_currentLoadedScene jsonString:jsonString];
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
  
  NSData *metOfficeData = [json dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:metOfficeData options:kNilOptions error:&error];
  if ([jsonObject isKindOfClass:[NSArray class]]) {
    NSArray *buttons = (NSArray *)jsonObject;
    for (NSDictionary *dictionary in buttons) {
      NSString *selections = dictionary[@"s"];
      if (namespaceString.length) {
        NSString *replacementString = [NSString stringWithFormat:@"u'%@", namespaceString];
        selections = [selections stringByReplacingOccurrencesOfString:@"u'" withString:replacementString];
      }
      CGPoint buttonCenter = CGPointMake([dictionary[@"x"] floatValue], [dictionary[@"y"] floatValue]);
      [self _addNewSelectionButtonWithItems:selections andName:dictionary[@"n"] atLocation:buttonCenter];
    }
  }
  if (_lockedScene) {
    [[[UIAlertView alloc] initWithTitle:@"Scene is locked" message:@"This scene is loaded from a referenced maya file.\nEditing for this scene is disabled. To edit this scene please open the referenced file." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil] show];
  }
}

@end
