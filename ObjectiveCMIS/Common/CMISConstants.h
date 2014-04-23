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

// Properties
extern NSString * const kCMISPropertyObjectId;
extern NSString * const kCMISPropertyName;
extern NSString * const kCMISPropertyPath;
extern NSString * const kCMISPropertyCreatedBy;
extern NSString * const kCMISPropertyCreationDate;
extern NSString * const kCMISPropertyModifiedBy;
extern NSString * const kCMISPropertyModificationDate;
extern NSString * const kCMISPropertyContentStreamId;
extern NSString * const kCMISPropertyContentStreamFileName;
extern NSString * const kCMISPropertyContentStreamLength;
extern NSString * const kCMISPropertyContentStreamMediaType;
extern NSString * const kCMISPropertyObjectTypeId;
extern NSString * const kCMISPropertyVersionSeriesId;
extern NSString * const kCMISPropertyVersionLabel;
extern NSString * const kCMISPropertyIsLatestVersion;
extern NSString * const kCMISPropertyIsMajorVersion;
extern NSString * const kCMISPropertyIsLatestMajorVersion;
extern NSString * const kCMISPropertyChangeToken;
extern NSString * const kCMISPropertyBaseTypeId;
extern NSString * const kCMISPropertyCheckinComment;
extern NSString * const kCMISPropertySecondaryObjectTypeIds;
extern NSString * const kCMISPropertyDescription;

// Property values
extern NSString * const kCMISPropertyObjectTypeIdValueDocument;
extern NSString * const kCMISPropertyObjectTypeIdValueFolder;

// Session cache keys
extern NSString * const kCMISSessionKeyWorkspaces;

// Capability Keys
extern NSString * const kCMISRepositoryCapabilityACL;
extern NSString * const kCMISRepositoryAllVersionsSearchable;
extern NSString * const kCMISRepositoryCapabilityChanges;
extern NSString * const kCMISRepositoryCapabilityContentStreamUpdatability;
extern NSString * const kCMISRepositoryCapabilityJoin;
extern NSString * const kCMISRepositoryCapabilityQuery;
extern NSString * const kCMISRepositoryCapabilityRenditions;
extern NSString * const kCMISRepositoryCapabilityPWCSearchable;
extern NSString * const kCMISRepositoryCapabilityPWCUpdatable;
extern NSString * const kCMISRepositoryCapabilityGetDescendants;
extern NSString * const kCMISRepositoryCapabilityGetFolderTree;
extern NSString * const kCMISRepositoryCapabilityOrderBy;
extern NSString * const kCMISRepositoryCapabilityMultifiling;
extern NSString * const kCMISRepositoryCapabilityUnfiling;
extern NSString * const kCMISRepositoryCapabilityVersionSpecificFiling;
extern NSString * const kCMISRepositoryCapabilityPropertyTypes;
extern NSString * const kCMISRepositoryCapabilityTypeSettableAttributes;