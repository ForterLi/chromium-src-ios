// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_CONTEXT_MENU_LINK_PREVIEW_LINK_PREVIEW_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_CONTEXT_MENU_LINK_PREVIEW_LINK_PREVIEW_MEDIATOR_H_

#import <Foundation/Foundation.h>
#include "url/gurl.h"

namespace web {
class WebState;
}

@protocol LinkPreviewConsumer;

// The preview mediator that observes changes of the model and updates the
// corresponding consumer.
@interface LinkPreviewMediator : NSObject

// The consumer that is updated by this mediator.
@property(nonatomic, weak) id<LinkPreviewConsumer> consumer;

// Init the LinkPreviewMediator with a |webState| and the first URL.
- (instancetype)initWithWebState:(web::WebState*)webState
                      previewURL:(const GURL&)previewURL;

@end

#endif  // IOS_CHROME_BROWSER_UI_CONTEXT_MENU_LINK_PREVIEW_LINK_PREVIEW_MEDIATOR_H_
