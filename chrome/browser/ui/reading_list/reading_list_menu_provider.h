// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_READING_LIST_READING_LIST_MENU_PROVIDER_H_
#define IOS_CHROME_BROWSER_UI_READING_LIST_READING_LIST_MENU_PROVIDER_H_

@class ReadingListListItem;

// Protocol for instances that will provide menus to ReadingList components.
@protocol ReadingListMenuProvider

// Creates a context menu configuration instance for the given |item|.
- (UIContextMenuConfiguration*)contextMenuConfigurationForItem:
    (id<ReadingListListItem>)item API_AVAILABLE(ios(13.0));

@end

#endif  // IOS_CHROME_BROWSER_UI_READING_LIST_READING_LIST_MENU_PROVIDER_H_
