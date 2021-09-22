// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/menu/action_factory.h"

#import "base/test/metrics/histogram_tester.h"
#import "base/test/task_environment.h"
#import "ios/chrome/browser/ui/menu/menu_action_type.h"
#import "ios/chrome/browser/ui/menu/menu_histograms.h"
#import "ios/chrome/grit/ios_strings.h"
#import "testing/gmock/include/gmock/gmock.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#import "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#import "third_party/ocmock/gtest_support.h"
#import "ui/base/l10n/l10n_util_mac.h"
#import "ui/base/test/ios/ui_image_test_utils.h"
#import "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
MenuScenario kTestMenuScenario = MenuScenario::kHistoryEntry;
}  // namespace

// Test fixture for the ActionFactory.
class ActionFactoryTest : public PlatformTest {
 protected:
  ActionFactoryTest() : test_title_(@"SomeTitle") {}

  // Creates a blue square.
  UIImage* CreateMockImage() {
    return ui::test::uiimage_utils::UIImageWithSizeAndSolidColor(
        CGSizeMake(10, 10), [UIColor blueColor]);
  }

  base::test::TaskEnvironment task_environment_;
  base::HistogramTester histogram_tester_;
  NSString* test_title_;
};

// Tests the creation of an action using the parameterized method, and verifies
// that the action has the right title and image.
TEST_F(ActionFactoryTest, CreateActionWithParameters) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* mockImage = CreateMockImage();

    UIAction* action = [factory actionWithTitle:test_title_
                                          image:mockImage
                                           type:MenuActionType::CopyURL
                                          block:^{
                                          }];

    EXPECT_TRUE([test_title_ isEqualToString:action.title]);
    EXPECT_EQ(mockImage, action.image);
  }
}

// Tests that the bookmark action has the right title and image.
TEST_F(ActionFactoryTest, BookmarkAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"bookmark"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_ADDTOBOOKMARKS);

    UIAction* action = [factory actionToBookmarkWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the close action has the right title and image.
TEST_F(ActionFactoryTest, CloseAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"close"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_CLOSETAB);

    UIAction* action = [factory actionToCloseTabWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the copy action has the right title and image.
TEST_F(ActionFactoryTest, CopyAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"copy_link_url"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_COPY_LINK_ACTION_TITLE);

    GURL testURL = GURL("https://example.com");

    UIAction* action = [factory actionToCopyURL:testURL];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the share action has the right title and image.
TEST_F(ActionFactoryTest, ShareAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"share"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_SHARE_BUTTON_LABEL);

    UIAction* action = [factory actionToShareWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the delete action has the right title and image.
TEST_F(ActionFactoryTest, DeleteAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"delete"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_DELETE_ACTION_TITLE);

    UIAction* action = [factory actionToDeleteWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
    EXPECT_EQ(UIMenuElementAttributesDestructive, action.attributes);
  }
}

// Tests that the read later action has the right title and image.
TEST_F(ActionFactoryTest, ReadLaterAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"read_later"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_ADDTOREADINGLIST);

    UIAction* action = [factory actionToAddToReadingListWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the remove action has the right title and image.
TEST_F(ActionFactoryTest, RemoveAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"remove"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_REMOVE_ACTION_TITLE);

    UIAction* action = [factory actionToRemoveWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the edit action has the right title and image.
TEST_F(ActionFactoryTest, EditAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"edit"];
    NSString* expectedTitle = l10n_util::GetNSString(IDS_IOS_EDIT_ACTION_TITLE);

    UIAction* action = [factory actionToEditWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the Open All Tabs action has the right title and image.
TEST_F(ActionFactoryTest, openAllTabsAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage systemImageNamed:@"plus"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_OPEN_ALL_LINKS);

    UIAction* action = [factory actionToOpenAllTabsWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the hide action has the right title and image.
TEST_F(ActionFactoryTest, hideAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"remove"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_RECENT_TABS_HIDE_MENU_OPTION);

    UIAction* action = [factory actionToHideWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the Move Folder action has the right title and image.
TEST_F(ActionFactoryTest, MoveFolderAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"move_folder"];

    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_BOOKMARK_CONTEXT_MENU_MOVE);

    UIAction* action = [factory actionToMoveFolderWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the Mark As Read action has the right title and image.
TEST_F(ActionFactoryTest, markAsReadAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"mark_read"];

    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_READING_LIST_MARK_AS_READ_ACTION);

    UIAction* action = [factory actionToMarkAsReadWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the Mark As Unread action has the right title and image.
TEST_F(ActionFactoryTest, markAsUnreadAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"remove"];

    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_READING_LIST_MARK_AS_UNREAD_ACTION);

    UIAction* action = [factory actionToMarkAsUnreadWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the View Offline Version in New Tab action has the right title and
// image.
TEST_F(ActionFactoryTest, viewOfflineVersion) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"offline"];

    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_READING_LIST_OPEN_OFFLINE_BUTTON);

    UIAction* action = [factory actionToOpenOfflineVersionInNewTabWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the save image action has the right title and image.
TEST_F(ActionFactoryTest, SaveImageAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"download"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_SAVEIMAGE);

    UIAction* action = [factory actionSaveImageWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the copy image action has the right title and image.
TEST_F(ActionFactoryTest, CopyImageAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"copy"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_COPYIMAGE);

    UIAction* action = [factory actionCopyImageWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the close all action has the right title and image.
TEST_F(ActionFactoryTest, CloseAllTabsAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"close"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_CLOSEALLTABS);

    UIAction* action = [factory actionToCloseAllTabsWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}

// Tests that the select tabs action has the right title and image.
TEST_F(ActionFactoryTest, SelectTabsAction) {
  if (@available(iOS 13.0, *)) {
    ActionFactory* factory =
        [[ActionFactory alloc] initWithScenario:kTestMenuScenario];

    UIImage* expectedImage = [UIImage imageNamed:@"select"];
    NSString* expectedTitle =
        l10n_util::GetNSString(IDS_IOS_CONTENT_CONTEXT_SELECTTABS);

    UIAction* action = [factory actionToSelectTabsWithBlock:^{
    }];

    EXPECT_TRUE([expectedTitle isEqualToString:action.title]);
    EXPECT_EQ(expectedImage, action.image);
  }
}
