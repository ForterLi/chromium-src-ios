// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_CREDENTIAL_PROVIDER_EXTENSION_UI_NEW_PASSWORD_TABLE_CELL_H_
#define IOS_CHROME_CREDENTIAL_PROVIDER_EXTENSION_UI_NEW_PASSWORD_TABLE_CELL_H_

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, NewPasswordTableCellType) {
  NewPasswordTableCellTypeUsername,
  NewPasswordTableCellTypePassword,
  NewPasswordTableCellTypeSuggestStrongPassword,
  NewPasswordTableCellTypeNumRows,
};

@interface NewPasswordTableCell : UITableViewCell

// Reuse ID for registering this class in table views.
@property(nonatomic, class, readonly) NSString* reuseID;

// Field that holds the user-entered text.
@property(nonatomic, strong) UITextField* textField;

// Sets the cell up to show the given type.
- (void)setCellType:(NewPasswordTableCellType)cellType;

@end

#endif  // IOS_CHROME_CREDENTIAL_PROVIDER_EXTENSION_UI_NEW_PASSWORD_TABLE_CELL_H_