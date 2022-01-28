// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/policy/policy_earl_grey_utils.h"

#include "base/json/json_string_value_serializer.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/policy/policy_app_interface.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Returns a JSON-encoded string representing the given |base::Value|. If
// |value| is nullptr, returns a string representing a |base::Value| of type
// NONE.
std::string SerializeValue(const base::Value value) {
  std::string serialized_value;
  JSONStringValueSerializer serializer(&serialized_value);
  serializer.Serialize(std::move(value));
  return serialized_value;
}
}  // namespace

namespace policy_test_utils {

void SetPolicy(bool enabled, const std::string& policy_key) {
  SetPolicy(base::Value(enabled), policy_key);
}

void SetPolicy(int value, const std::string& policy_key) {
  SetPolicy(base::Value(value), policy_key);
}

void SetPolicyWithStringValue(const std::string& value,
                              const std::string& policy_key) {
  SetPolicy(base::Value(value), policy_key);
}

void SetPolicy(const std::string& json_value, const std::string& policy_key) {
  [PolicyAppInterface setPolicyValue:base::SysUTF8ToNSString(json_value)
                              forKey:base::SysUTF8ToNSString(policy_key)];
}

void SetPolicy(base::Value value, const std::string& policy_key) {
  SetPolicy(SerializeValue(std::move(value)), policy_key);
}

}  // namespace policy_test_utils
