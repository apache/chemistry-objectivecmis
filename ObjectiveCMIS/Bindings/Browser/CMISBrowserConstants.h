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

@interface CMISBrowserConstants : NSObject

// Session keys
extern NSString * const kCMISBrowserBindingSessionKeyRepositoryUrl;
extern NSString * const kCMISBrowserBindingSessionKeyRootFolderUrl;

// JSON properties
extern NSString * const kCMISBrowserJSONRepositoryId;
extern NSString * const kCMISBrowserJSONRepositoryName;
extern NSString * const kCMISBrowserJSONRepositoryDescription;
extern NSString * const kCMISBrowserJSONVendorName;
extern NSString * const kCMISBrowserJSONProductName;
extern NSString * const kCMISBrowserJSONProductVersion;
extern NSString * const kCMISBrowserJSONRootFolderId;
extern NSString * const kCMISBrowserJSONCapabilities;
extern NSString * const kCMISBrowserJSONCMISVersionSupported;
extern NSString * const kCMISBrowserJSONPrincipalIdAnonymous;
extern NSString * const kCMISBrowserJSONPrincipalIdAnyone;
extern NSString * const kCMISBrowserJSONRepositoryUrl;
extern NSString * const kCMISBrowserJSONRootFolderUrl;
extern NSString * const kCMISBrowserJSONId;
extern NSString * const kCMISBrowserJSONLocalName;
extern NSString * const kCMISBrowserJSONLocalNamespace;
extern NSString * const kCMISBrowserJSONDisplayName;
extern NSString * const kCMISBrowserJSONQueryName;
extern NSString * const kCMISBrowserJSONDescription;
extern NSString * const kCMISBrowserJSONBaseId;
extern NSString * const kCMISBrowserJSONCreateable;
extern NSString * const kCMISBrowserJSONFileable;
extern NSString * const kCMISBrowserJSONQueryable;
extern NSString * const kCMISBrowserJSONFullTextIndexed;
extern NSString * const kCMISBrowserJSONIncludedInSuperTypeQuery;
extern NSString * const kCMISBrowserJSONControllablePolicy;
extern NSString * const kCMISBrowserJSONControllableAcl;
extern NSString * const kCMISBrowserJSONPropertyDefinitions;
extern NSString * const kCMISBrowserJSONPropertyType;
extern NSString * const kCMISBrowserJSONCardinality;
extern NSString * const kCMISBrowserJSONUpdateability;
extern NSString * const kCMISBrowserJSONInherited;
extern NSString * const kCMISBrowserJSONRequired;
extern NSString * const kCMISBrowserJSONOrderable;
extern NSString * const kCMISBrowserJSONSuccinctProperties;
extern NSString * const kCMISBrowserJSONObjects;
extern NSString * const kCMISBrowserJSONObject;
extern NSString * const kCMISBrowserJSONHasMoreItems;
extern NSString * const kCMISBrowserJSONNumberItems;

// JSON enum values
extern NSString * const kCMISBrowserJSONPropertyTypeValueString;
extern NSString * const kCMISBrowserJSONPropertyTypeValueId;
extern NSString * const kCMISBrowserJSONPropertyTypeValueInteger;
extern NSString * const kCMISBrowserJSONPropertyTypeValueDecimal;
extern NSString * const kCMISBrowserJSONPropertyTypeValueBoolean;
extern NSString * const kCMISBrowserJSONPropertyTypeValueDateTime;
extern NSString * const kCMISBrowserJSONPropertyTypeValueHtml;
extern NSString * const kCMISBrowserJSONPropertyTypeValueUri;
extern NSString * const kCMISBrowserJSONCardinalityValueSingle;
extern NSString * const kCMISBrowserJSONCardinalityValueMultiple;
extern NSString * const kCMISBrowserJSONUpdateabilityValueReadOnly;
extern NSString * const kCMISBrowserJSONUpdateabilityValueReadWrite;
extern NSString * const kCMISBrowserJSONUpdateabilityValueOnCreate;
extern NSString * const kCMISBrowserJSONUpdateabilityValueWhenCheckedOut;




@end
