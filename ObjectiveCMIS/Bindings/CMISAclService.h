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
#import "CMISEnums.h"

@class CMISExtensionData;
@class CMISAcl;
@class CMISRequest;

@protocol CMISAclService <NSObject>

/**
 * Retrieves the acl of an object with the given object identifier.
 * completionBlock returns acl for an object or nil if unsuccessful
 */
- (CMISRequest*)retrieveAcl:objectId
       onlyBasicPermissions:(BOOL)onlyBasicPermissions
            completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock;

/**
 * Removes and adds the specified acl to an object with the given object identifier.
 * completionBlock returns acl for an object or nil if unsuccessful
 */
- (CMISRequest*)applyAcl:objectId
                 addAces:(CMISAcl *)addAces
              removeAces:(CMISAcl *)removeAces
          aclPropagation:(CMISAclPropagation)aclPropagation
         completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock;

/**
 * Sets the specified acl to an object with the given object identifier.
 * completionBlock returns acl for an object or nil if unsuccessful
 */
- (CMISRequest*)setAcl:objectId
                  aces:(CMISAcl *)aces
       completionBlock:(void (^)(CMISAcl *acl, NSError *error))completionBlock;

@end
