// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/popup_menu/cells/popup_menu_tools_item.h"

#include "base/logging.h"
#import "ios/chrome/browser/ui/util/constraints_ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const CGFloat kImageLength = 30;
const CGFloat kMargin = 8;
}

@implementation PopupMenuToolsItem

@synthesize actionIdentifier = _actionIdentifier;
@synthesize image = _image;
@synthesize title = _title;

- (instancetype)initWithType:(NSInteger)type {
  self = [super initWithType:type];
  if (self) {
    self.cellClass = [PopupMenuToolsCell class];
  }
  return self;
}

- (void)configureCell:(PopupMenuToolsCell*)cell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:cell withStyler:styler];
  cell.titleLabel.text = self.title;
  cell.imageView.image = self.image;
}

#pragma mark - PopupMenuItem

- (CGSize)cellSizeForWidth:(CGFloat)width {
  return [self.cellClass sizeForWidth:width title:self.title];
}

@end

#pragma mark - PopupMenuToolsCell

@interface PopupMenuToolsCell ()

// Title label for the cell, redefined as readwrite.
@property(nonatomic, strong, readwrite) UILabel* titleLabel;
// Image view for the cell, redefined as readwrite.
@property(nonatomic, strong, readwrite) UIImageView* imageView;

@end

@implementation PopupMenuToolsCell

@synthesize imageView = _imageView;
@synthesize titleLabel = _titleLabel;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString*)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.numberOfLines = 0;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_imageView.widthAnchor constraintEqualToConstant:kImageLength],
      [_imageView.heightAnchor
          constraintGreaterThanOrEqualToConstant:kImageLength],
    ]];

    [self.contentView addSubview:_titleLabel];
    [self.contentView addSubview:_imageView];

    AddSameConstraintsToSides(self.contentView, _titleLabel,
                              LayoutSides::kTop | LayoutSides::kBottom);
    AddSameConstraintsToSides(
        self.contentView, _imageView,
        LayoutSides::kTop | LayoutSides::kBottom | LayoutSides::kLeading);
    [_imageView.trailingAnchor
        constraintEqualToAnchor:_titleLabel.leadingAnchor]
        .active = YES;
    [_titleLabel.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:-kMargin]
        .active = YES;
  }
  return self;
}

+ (CGSize)sizeForWidth:(CGFloat)width title:(NSString*)title {
  // This is not using a prototype cell and autolayout for performance reasons.
  CGFloat nonTitleElementWidth = kImageLength + kMargin;
  // The width should be enough to contain more than the image.
  DCHECK(width > nonTitleElementWidth);

  CGSize titleSize = CGSizeMake(width - nonTitleElementWidth,
                                [UIScreen mainScreen].bounds.size.height);
  NSDictionary* attributes = @{NSFontAttributeName : [self cellFont]};
  CGRect rectForString =
      [title boundingRectWithSize:titleSize
                          options:NSStringDrawingUsesLineFragmentOrigin
                       attributes:attributes
                          context:nil];
  CGSize size = rectForString.size;
  size.height = MAX(size.height, kImageLength);
  size.width += nonTitleElementWidth;
  return size;
}

#pragma mark - Private

+ (UIFont*)cellFont {
  static UIFont* font;
  if (!font) {
    PopupMenuToolsCell* cell =
        [[PopupMenuToolsCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:@"fakeID"];
    font = cell.titleLabel.font;
  }
  return font;
}

@end
