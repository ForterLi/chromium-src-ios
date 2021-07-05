// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_TAB_SWITCHER_TAB_GRID_TAB_GRID_CONSTANTS_H_
#define IOS_CHROME_BROWSER_UI_TAB_SWITCHER_TAB_GRID_TAB_GRID_CONSTANTS_H_

#include <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// Accessibility identifiers for automated testing.
extern NSString* const kTabGridIncognitoTabsPageButtonIdentifier;
extern NSString* const kTabGridRegularTabsPageButtonIdentifier;
extern NSString* const kTabGridRemoteTabsPageButtonIdentifier;
extern NSString* const kTabGridDoneButtonIdentifier;
extern NSString* const kTabGridCloseAllButtonIdentifier;
extern NSString* const kTabGridUndoCloseAllButtonIdentifier;
extern NSString* const kTabGridIncognitoTabsEmptyStateIdentifier;
extern NSString* const kTabGridRegularTabsEmptyStateIdentifier;
extern NSString* const kTabGridScrollViewIdentifier;
extern NSString* const kRegularTabGridIdentifier;
extern NSString* const kIncognitoTabGridIdentifier;

extern NSString* const kTabGridEditButtonIdentifier;
extern NSString* const kTabGridEditCloseTabsButtonIdentifier;
extern NSString* const kTabGridEditSelectAllButtonIdentifier;
extern NSString* const kTabGridEditAddToButtonIdentifier;
extern NSString* const kTabGridEditShareButtonIdentifier;

// All kxxxColor constants are RGB values stored in a Hex integer. These will be
// converted into UIColors using the UIColorFromRGB() function, from
// uikit_ui_util.h

// The color of the text buttons in the toolbars.
extern const int kTabGridToolbarTextButtonColor;

// Colors for the empty state.
extern const int kTabGridEmptyStateTitleTextColor;
extern const int kTabGridEmptyStateBodyTextColor;

// The distance the toolbar content is inset from either side.
extern const CGFloat kTabGridToolbarHorizontalInset;

// The distance between the title and body of the empty state view.
extern const CGFloat kTabGridEmptyStateVerticalMargin;

// The insets from the edges for empty state.
extern const CGFloat kTabGridEmptyStateVerticalInset;
extern const CGFloat kTabGridEmptyStateHorizontalInset;

// The insets from the edges for the floating button.
extern const CGFloat kTabGridFloatingButtonVerticalInset;
extern const CGFloat kTabGridFloatingButtonHorizontalInset;

// Intrinsic heights of the tab grid toolbars.
extern const CGFloat kTabGridTopToolbarHeight;
extern const CGFloat kTabGridBottomToolbarHeight;

// The distance travelled by the thumb strip thumbnails during the slide-in
// animation of the thumb strip reveal transition.
extern const CGFloat kThumbStripSlideInHeight;

// The distance travelled by the thumb strip's plus sign button during the
// slide-out animation of the transition from Peeked to Revealed state.
extern const CGFloat kThumbStripPlusSignButtonSlideOutDistance;

#endif  // IOS_CHROME_BROWSER_UI_TAB_SWITCHER_TAB_GRID_TAB_GRID_CONSTANTS_H_
