// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/credential_provider_extension/password_spec_fetcher.h"

#include "base/base64.h"
#include "components/autofill/core/browser/proto/password_requirements.pb.h"
#include "ios/chrome/credential_provider_extension/password_spec_fetcher_buildflags.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using autofill::DomainSuggestions;
using autofill::PasswordRequirementsSpec;

namespace {

// URL of the fetching endpoint.
NSString* const kPasswordSpecURL =
    @"https://content-autofill.googleapis.com/v1/domainSuggestions/";
// API key to query the spec. Defined as a buildflag.
NSString* const kApiKeyValue = BUILDFLAG(GOOGLE_API_KEY);
// Header field name for the API key.
NSString* const kApiKeyHeaderField = @"X-Goog-Api-Key";
// Encoding requested from the server.
NSString* const kEncodeKeyValue = @"base64";
// Header field name for the encoding.
NSString* const kEncodeKeyHeaderField = @"X-Goog-Encode-Response-If-Executable";
// Query parameter name to for the type of response.
NSString* const kAltQueryName = @"alt";
// Query parameter value for a bits response (compared to a JSON response).
NSString* const kAltQueryValue = @"proto";
// Timeout for the spec fetching request.
const NSTimeInterval kPasswordSpecTimeout = 10;

}

@interface PasswordSpecFetcher ()

// Host that identifies the spec to be fetched.
@property(nonatomic, copy) NSString* host;

// Data task for fetching the spec.
@property(nonatomic, copy) NSURLSessionDataTask* task;

// Completion to be called once there is a response.
@property(nonatomic, copy) FetchSpecCompletionBlock completion;

// The spec if ready or an empty one if fetch hasn't happened.
@property(nonatomic, readwrite) PasswordRequirementsSpec spec;

@end

@implementation PasswordSpecFetcher

- (instancetype)initWithHost:(NSString*)host {
  self = [super init];
  if (self) {
    _host = [host stringByAddingPercentEncodingWithAllowedCharacters:
                      NSCharacterSet.URLQueryAllowedCharacterSet];
  }
  return self;
}

- (BOOL)didFetchSpec {
  return self.task.state == NSURLSessionTaskStateCompleted;
}

- (void)fetchSpecWithCompletion:(FetchSpecCompletionBlock)completion {
  self.completion = completion;

  if (self.task) {
    return;
  }
  NSString* finalURL = [kPasswordSpecURL stringByAppendingString:self.host];
  NSURLComponents* URLComponents =
      [NSURLComponents componentsWithString:finalURL];
  NSURLQueryItem* queryAltItem =
      [NSURLQueryItem queryItemWithName:kAltQueryName value:kAltQueryValue];
  URLComponents.queryItems = @[ queryAltItem ];
  NSMutableURLRequest* request =
      [NSMutableURLRequest requestWithURL:URLComponents.URL
                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                          timeoutInterval:kPasswordSpecTimeout];
  [request setValue:kApiKeyValue forHTTPHeaderField:kApiKeyHeaderField];
  [request setValue:kEncodeKeyValue forHTTPHeaderField:kEncodeKeyHeaderField];

  __weak __typeof__(self) weakSelf = self;
  NSURLSession* session = [NSURLSession sharedSession];
  self.task =
      [session dataTaskWithRequest:request
                 completionHandler:^(NSData* data, NSURLResponse* response,
                                     NSError* error) {
                   [weakSelf onReceivedData:data response:response error:error];
                 }];
  [self.task resume];
}

- (void)onReceivedData:(NSData*)data
              response:(NSURLResponse*)response
                 error:(NSError*)error {
  // Return early if there is an error.
  if (error) {
    [self executeCompletion];
    return;
  }

  // Parse the proto and execute completion.
  std::string decoded;
  const char* bytes = static_cast<const char*>([data bytes]);
  if (base::Base64Decode(bytes, &decoded)) {
    DomainSuggestions suggestions;
    suggestions.ParseFromString(decoded);
    if (suggestions.has_password_requirements()) {
      self.spec = suggestions.password_requirements();
    }
  }
  [self executeCompletion];
}

// Executes the completion if present. And releases it after.
- (void)executeCompletion {
  if (self.completion) {
    auto completion = self.completion;
    self.completion = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(self.spec);
    });
  }
}

@end
