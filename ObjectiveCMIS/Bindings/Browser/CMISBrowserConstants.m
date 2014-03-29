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

#import "CMISBrowserConstants.h"

@implementation CMISBrowserConstants

// Session keys
NSString * const kCMISBrowserBindingSessionKeyRepositoryUrl = @"cmis_session_key_browser_repo_url";
NSString * const kCMISBrowserBindingSessionKeyRootFolderUrl = @"cmis_session_key_browser_root_folder_url";

// JSON properties
NSString * const kCMISBrowserJSONRepositoryId = @"repositoryId";
NSString * const kCMISBrowserJSONRepositoryName = @"repositoryName";
NSString * const kCMISBrowserJSONRepositoryDescription = @"repositoryDescription";
NSString * const kCMISBrowserJSONVendorName = @"vendorName";
NSString * const kCMISBrowserJSONProductName = @"productName";
NSString * const kCMISBrowserJSONProductVersion = @"productVersion";
NSString * const kCMISBrowserJSONRootFolderId = @"rootFolderId";
NSString * const kCMISBrowserJSONCapabilities = @"capabilities";
NSString * const kCMISBrowserJSONCMISVersionSupported = @"cmisVersionSupported";
NSString * const kCMISBrowserJSONPrincipalIdAnonymous = @"principalIdAnonymous";
NSString * const kCMISBrowserJSONPrincipalIdAnyone = @"principalIdAnyone";
NSString * const kCMISBrowserJSONRepositoryUrl = @"repositoryUrl";
NSString * const kCMISBrowserJSONRootFolderUrl = @"rootFolderUrl";
NSString * const kCMISBrowserJSONId = @"id";
NSString * const kCMISBrowserJSONLocalName = @"localName";
NSString * const kCMISBrowserJSONLocalNamespace = @"localNamespace";
NSString * const kCMISBrowserJSONDisplayName = @"displayName";
NSString * const kCMISBrowserJSONQueryName = @"queryName";
NSString * const kCMISBrowserJSONDescription = @"description";
NSString * const kCMISBrowserJSONBaseId = @"baseId";
NSString * const kCMISBrowserJSONCreateable = @"creatable";
NSString * const kCMISBrowserJSONFileable = @"fileable";
NSString * const kCMISBrowserJSONQueryable = @"queryable";
NSString * const kCMISBrowserJSONFullTextIndexed = @"fulltextIndexed";
NSString * const kCMISBrowserJSONIncludedInSuperTypeQuery = @"includedInSupertypeQuery";
NSString * const kCMISBrowserJSONControllablePolicy = @"controllablePolicy";
NSString * const kCMISBrowserJSONControllableAcl = @"controllableACL";
NSString * const kCMISBrowserJSONPropertyDefinitions = @"propertyDefinitions";
NSString * const kCMISBrowserJSONPropertyType = @"propertyType";
NSString * const kCMISBrowserJSONCardinality = @"cardinality";
NSString * const kCMISBrowserJSONUpdateability = @"updatability";
NSString * const kCMISBrowserJSONInherited = @"inherited";
NSString * const kCMISBrowserJSONRequired = @"required";
NSString * const kCMISBrowserJSONOrderable = @"orderable";
NSString * const kCMISBrowserJSONSuccinctProperties = @"succinctProperties";
NSString * const kCMISBrowserJSONObjects = @"objects";
NSString * const kCMISBrowserJSONObject = @"object";
NSString * const kCMISBrowserJSONHasMoreItems = @"hasMoreItems";
NSString * const kCMISBrowserJSONNumberItems = @"numItems";

// JSON enum values
NSString * const kCMISBrowserJSONPropertyTypeValueString = @"string";
NSString * const kCMISBrowserJSONPropertyTypeValueId = @"id";
NSString * const kCMISBrowserJSONPropertyTypeValueInteger = @"integer";
NSString * const kCMISBrowserJSONPropertyTypeValueDecimal = @"decimal";
NSString * const kCMISBrowserJSONPropertyTypeValueBoolean = @"boolean";
NSString * const kCMISBrowserJSONPropertyTypeValueDateTime = @"datetime";
NSString * const kCMISBrowserJSONPropertyTypeValueHtml = @"html";
NSString * const kCMISBrowserJSONPropertyTypeValueUri = @"uri";

NSString * const kCMISBrowserJSONCardinalityValueSingle = @"single";
NSString * const kCMISBrowserJSONCardinalityValueMultiple = @"multi";

NSString * const kCMISBrowserJSONUpdateabilityValueReadOnly = @"readonly";
NSString * const kCMISBrowserJSONUpdateabilityValueReadWrite = @"readwrite";
NSString * const kCMISBrowserJSONUpdateabilityValueOnCreate = @"oncreate";
NSString * const kCMISBrowserJSONUpdateabilityValueWhenCheckedOut = @"whencheckedout";

@end
