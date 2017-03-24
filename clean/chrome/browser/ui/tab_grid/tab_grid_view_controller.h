// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CLEAN_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_VIEW_CONTROLLER_H_
#define IOS_CLEAN_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/clean/chrome/browser/ui/animators/zoom_transition_delegate.h"
#import "ios/clean/chrome/browser/ui/tab_grid/tab_grid_consumer.h"

@protocol SettingsCommands;
@protocol TabCommands;
@protocol TabGridCommands;
@protocol TabGridDataSource;

// Controller for a scrolling view displaying square cells that represent
// the user's open tabs.
@interface TabGridViewController
    : UIViewController<TabGridConsumer, ZoomTransitionDelegate>
// Data source for the tabs to be displayed.
@property(nonatomic, weak) id<TabGridDataSource> dataSource;
// Command handlers.
@property(nonatomic, weak) id<SettingsCommands> settingsCommandHandler;
@property(nonatomic, weak) id<TabCommands> tabCommandHandler;
@property(nonatomic, weak) id<TabGridCommands> tabGridCommandHandler;
@end

#endif  // IOS_CLEAN_CHROME_BROWSER_UI_TAB_GRID_TAB_GRID_VIEW_CONTROLLER_H_
