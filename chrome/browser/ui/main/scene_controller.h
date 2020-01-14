// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_MAIN_SCENE_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_MAIN_SCENE_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/app/application_delegate/tab_switching.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/main/scene_controller_guts.h"
#import "ios/chrome/browser/ui/main/scene_state.h"
#import "ios/chrome/browser/ui/tab_grid/tab_switcher.h"
#import "ios/chrome/browser/url_loading/app_url_loading_service.h"

@protocol MainControllerGuts;

// The controller object for a scene. Reacts to scene state changes.
@interface SceneController : NSObject <AppURLLoadingServiceDelegate,
                                       SceneStateObserver,
                                       ApplicationCommands,
                                       TabSwitcherDelegate,
                                       TabSwitching,
                                       SceneControllerGuts>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSceneState:(SceneState*)sceneState
    NS_DESIGNATED_INITIALIZER;

// The state of the scene controlled by this object.
@property(nonatomic, weak, readonly) SceneState* sceneState;

// Returns whether the scene is showing or partially showing the
// incognito panel.
@property(nonatomic, assign, readonly) BOOL incognitoContentVisible;

// A temporary pointer to MainController.
@property(nonatomic, weak) id<MainControllerGuts> mainController;

@end

#endif  // IOS_CHROME_BROWSER_UI_MAIN_SCENE_CONTROLLER_H_
