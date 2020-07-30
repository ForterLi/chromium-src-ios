// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_RECENT_TABS_RECENT_TABS_MENU_PROVIDER_H_
#define IOS_CHROME_BROWSER_UI_RECENT_TABS_RECENT_TABS_MENU_PROVIDER_H_

@class TableViewURLItem;

// Protocol for instances that will provide menus to RecentTabs components.
@protocol RecentTabsMenuProvider

// Creates a context menu configuration instance for the given |item|.
- (UIContextMenuConfiguration*)contextMenuConfigurationForItem:
    (TableViewURLItem*)item API_AVAILABLE(ios(13.0));

// Creates a context menu configuration instance for the header of the given
// |sectionIdentifier|.
- (UIContextMenuConfiguration*)
    contextMenuConfigurationForHeaderWithSectionIdentifier:
        (NSInteger)sectionIdentifier API_AVAILABLE(ios(13.0));

@end

#endif  // IOS_CHROME_BROWSER_UI_RECENT_TABS_RECENT_TABS_MENU_PROVIDER_H_
