/*
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
 */

#import <Foundation/Foundation.h>

@class CMISLinkRelations;
@class CMISBindingSession;


@interface CMISLinkCache : NSObject

/// initialise with CMISBindingSession instance
- (id)initWithBindingSession:(CMISBindingSession *)bindingSession;

/// retrieves the link for a given object Id/relationship
- (NSString *)linkForObjectId:(NSString *)objectId andRelation:(NSString *)rel;

/// retrieves the link for a given objectId, relationship and type
- (NSString *)linkForObjectId:(NSString *)objectId andRelation:(NSString *)rel andType:(NSString *)type;

/// adds a link for object Id
- (void)addLinks:(CMISLinkRelations *)links forObjectId:(NSString *)objectId;

/// removes link for object Id
- (void)removeLinksForObjectId:(NSString *)objectId;

/**
 * removes all links
 */
- (void)removeAllLinks;

@end