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
extern NSString * const kCMISPropertyObjectTypeIdValueRelationship;
extern NSString * const kCMISPropertyObjectTypeIdValuePolicy;
extern NSString * const kCMISPropertyObjectTypeIdValueItem;
extern NSString * const kCMISPropertyObjectTypeIdValueSecondary;

// Session cache keys

extern NSString * const kCMISSessionKeyWorkspaces;

// URL parameters
extern NSString * const kCMISParameterChangeToken;
extern NSString * const kCMISParameterOverwriteFlag;
extern NSString * const kCMISParameterIncludeAllowableActions;
extern NSString * const kCMISParameterFilter;
extern NSString * const kCMISParameterMaxItems;
extern NSString * const kCMISParameterObjectId;
extern NSString * const kCMISParameterOrderBy;
extern NSString * const kCMISParameterIncludePathSegment;
extern NSString * const kCMISParameterIncludeRelationships;
extern NSString * const kCMISParameterIncludePolicyIds;
extern NSString * const kCMISParameterIncludeAcl;
extern NSString * const kCMISParameterRenditionFilter;
extern NSString * const kCMISParameterSkipCount;
extern NSString * const kCMISParameterStreamId;
extern NSString * const kCMISParameterAllVersions;
extern NSString * const kCMISParameterContinueOnFailure;
extern NSString * const kCMISParameterUnfileObjects;
extern NSString * const kCMISParameterRelativePathSegment;
extern NSString * const kCMISParameterMajor;
extern NSString * const kCMISParameterCheckin;
extern NSString * const kCMISParameterCheckinComment;
extern NSString * const kCMISParameterSelector;
extern NSString * const kCMISParameterSuccinct;
extern NSString * const kCMISParameterReturnVersion;
extern NSString * const kCMISParameterTypeId;

// Parameter Values
extern NSString * const kCMISParameterValueTrue;
extern NSString * const kCMISParameterValueFalse;
extern NSString * const kCMISParameterValueReturnValueThis;
extern NSString * const kCMISParameterValueReturnValueLatest;
extern NSString * const kCMISParameterValueReturnValueLatestMajor;

//ContentStreamAllowed enum values
extern NSString * const kCMISContentStreamAllowedValueRequired;
extern NSString * const kCMISContentStreamAllowedValueAllowed;
extern NSString * const kCMISContentStreamAllowedValueNotAllowed;