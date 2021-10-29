// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_PUBLIC_JS_MESSAGING_FUZZER_SUPPORT_FUZZER_UTIL_H_
#define IOS_WEB_PUBLIC_JS_MESSAGING_FUZZER_SUPPORT_FUZZER_UTIL_H_

#include <memory>

#include "ios/web/public/js_messaging/fuzzer_support/js_message.pb.h"

namespace web {

class ScriptMessage;

namespace fuzzer {

// Converts a |ScriptMessageProto| to |ScriptMessage|.
std::unique_ptr<web::ScriptMessage> ProtoToScriptMessage(
    const web::ScriptMessageProto& proto);
}  // namespace fuzzer

}  // namespace web

#endif  // IOS_WEB_PUBLIC_JS_MESSAGING_FUZZER_SUPPORT_FUZZER_UTIL_H_
