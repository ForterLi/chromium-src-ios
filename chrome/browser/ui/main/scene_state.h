// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_MAIN_SCENE_STATE_H_
#define IOS_CHROME_BROWSER_UI_MAIN_SCENE_STATE_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/scoped_ui_blocker/ui_blocker_target.h"
#import "ios/chrome/browser/window_activities/window_activity_helpers.h"

@class AppState;
@class SceneController;
@class SceneState;
@protocol BrowserInterfaceProvider;

// Describes the possible scene states.
// This is an iOS 12 compatible version of UISceneActivationState enum.
typedef NS_ENUM(NSUInteger, SceneActivationLevel) {
  // The scene is not connected and has no window.
  SceneActivationLevelUnattached = 0,
  // The scene is connected, and has a window associated with it. The window is
  // not visible to the user, except possibly in the app switcher.
  SceneActivationLevelBackground,
  // The scene is connected, and its window is on screen, but it's not active
  // for user input. For example, keyboard events would not be sent to this
  // window.
  SceneActivationLevelForegroundInactive,
  // The scene is connected, has a window, and receives user events.
  SceneActivationLevelForegroundActive
};

// Scene agents are objects owned by a scene state and providing some
// scene-scoped function. They can be driven by SceneStateObserver events.
@protocol SceneAgent <NSObject>

@required
// Sets the associated scene state. Called once and only once. Consider using
// this method to add the agent as an observer.
- (void)setSceneState:(SceneState*)scene;

@end

@protocol SceneStateObserver <NSObject>

@optional

// Called whenever the scene state transitions between different activity
// states.
- (void)sceneState:(SceneState*)sceneState
    transitionedToActivationLevel:(SceneActivationLevel)level;

// Notifies when presentingModalOverlay is being set to true.
- (void)sceneStateWillShowModalOverlay:(SceneState*)sceneState;
// Notifies when presentingModalOverlay is being set to false.
- (void)sceneStateWillHideModalOverlay:(SceneState*)sceneState;
// Notifies when URLContexts have been added to |URLContextsToOpen|.
- (void)sceneState:(SceneState*)sceneState
    hasPendingURLs:(NSSet<UIOpenURLContext*>*)URLContexts
    API_AVAILABLE(ios(13));
// Notifies that a new activity request has been received.
- (void)sceneState:(SceneState*)sceneState
    receivedUserActivity:(NSUserActivity*)userActivity;

@end

// An object containing the state of a UIWindowScene. One state object
// corresponds to one scene.
@interface SceneState : NSObject <UIBlockerTarget>

- (instancetype)initWithAppState:(AppState*)appState NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// The app state for the app that owns this scene. Set in init.
@property(nonatomic, weak, readonly) AppState* appState;

// The current activation level.
@property(nonatomic, assign) SceneActivationLevel activationLevel;

// The current origin of the scene.  After window creation this will be
// WindowActivityRestoredOrigin.
@property(nonatomic, assign) WindowActivityOrigin currentOrigin;

// YES if some incognito content is visible, for example an incognito tab or the
// incognito tab switcher.
@property(nonatomic) BOOL incognitoContentVisible;

// Window for the associated scene, if any.
@property(nonatomic, strong) UIWindow* window;

@property(nonatomic, weak) UIWindowScene* scene API_AVAILABLE(ios(13));

@property(nonatomic, strong)
    UISceneConnectionOptions* connectionOptions API_AVAILABLE(ios(13));

// The interface provider associated with this scene.
@property(nonatomic, strong, readonly) id<BrowserInterfaceProvider>
    interfaceProvider;

// True if First Run UI (terms of service & sync sign-in) is being presented
// in a modal dialog.
@property(nonatomic, assign) BOOL presentingFirstRunUI;

// The controller for this scene.
@property(nonatomic, weak) SceneController* controller;

// When this is YES, the scene is showing the modal overlay.
@property(nonatomic, assign) BOOL presentingModalOverlay;

// URLs passed to |UIWindowSceneDelegate scene:openURLContexts:| that needs to
// be open next time the scene is activated.
// Setting the property to not nil will add the new URL contexts to the set.
// Setting the property to nil will clear the set.
@property(nonatomic)
    NSSet<UIOpenURLContext*>* URLContextsToOpen API_AVAILABLE(ios(13));

// A NSUserActivity that has been passed to
// |UISceneDelegate scene:continueUserActivity:| and needs to be opened.
@property(nonatomic) NSUserActivity* pendingUserActivity;

// Adds an observer to this scene state. The observers will be notified about
// scene state changes per SceneStateObserver protocol.
- (void)addObserver:(id<SceneStateObserver>)observer;
// Removes the observer. It's safe to call this at any time, including from
// SceneStateObserver callbacks.
- (void)removeObserver:(id<SceneStateObserver>)observer;

// Adds a new agent. Agents are owned by the scene state.
- (void)addAgent:(id<SceneAgent>)agent;

@end

#endif  // IOS_CHROME_BROWSER_UI_MAIN_SCENE_STATE_H_
