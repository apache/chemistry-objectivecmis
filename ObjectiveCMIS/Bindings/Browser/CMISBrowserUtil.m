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

#import "CMISBrowserUtil.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISRepositoryInfo.h"
#import "CMISPropertyDefinition.h"

@implementation CMISBrowserUtil

+ (NSDictionary *)repositoryInfoDictionaryFromJSONData:(NSData *)jsonData bindingSession:(CMISBindingSession *)bindingSession error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    NSMutableDictionary *repositories = nil;
    if (!serialisationError) {
        repositories = [NSMutableDictionary dictionary];
        
        // parse the json into CMISRepositoryInfo objects and store in self.repositories
        NSArray *repos = [jsonDictionary allValues];
        for (NSDictionary *repo in repos) {
            CMISRepositoryInfo *repoInfo = [CMISRepositoryInfo new];
            repoInfo.identifier = repo[kCMISBrowserJSONRepositoryId];
            repoInfo.name = repo[kCMISBrowserJSONRepositoryName];
            repoInfo.desc = repo[kCMISBrowserJSONRepositoryDescription];
            repoInfo.rootFolderId = repo[kCMISBrowserJSONRootFolderId];
            repoInfo.cmisVersionSupported = repo[kCMISBrowserJSONCMISVersionSupported];
            repoInfo.productName = repo[kCMISBrowserJSONProductName];
            repoInfo.productVersion = repo[kCMISBrowserJSONProductVersion];
            repoInfo.vendorName = repo[kCMISBrowserJSONVendorName];
            repoInfo.principalIdAnonymous = repo[kCMISBrowserJSONPrincipalIdAnonymous];
            repoInfo.principalIdAnyone = repo[kCMISBrowserJSONPrincipalIdAnyone];
            
            // store the repo and root folder URLs in the session (when the repoId matches)
            if ([repoInfo.identifier isEqualToString:bindingSession.repositoryId]) {
                [bindingSession setObject:repo[kCMISBrowserJSONRootFolderUrl] forKey:kCMISBrowserBindingSessionKeyRootFolderUrl];
                [bindingSession setObject:repo[kCMISBrowserJSONRepositoryUrl] forKey:kCMISBrowserBindingSessionKeyRepositoryUrl];
            }
            
            [repositories setObject:repoInfo forKey:repoInfo.identifier];
        }
    }

    return repositories;
}

+ (CMISTypeDefinition *)typeDefinitionFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISTypeDefinition *typeDef = nil;
    if (!serialisationError) {
        typeDef = [CMISTypeDefinition new];
        typeDef.id = jsonDictionary[kCMISBrowserJSONId];
        typeDef.localName = jsonDictionary[kCMISBrowserJSONLocalName];
        typeDef.localNameSpace = jsonDictionary[kCMISBrowserJSONLocalNamespace];
        typeDef.displayName = jsonDictionary[kCMISBrowserJSONDisplayName];
        typeDef.queryName = jsonDictionary[kCMISBrowserJSONQueryName];
        typeDef.description = jsonDictionary[kCMISBrowserJSONDescription];
        
        NSString *baseIdString = jsonDictionary[kCMISBrowserJSONBaseId];
        if ([baseIdString isEqualToString:kCMISPropertyObjectTypeIdValueDocument]) {
            typeDef.baseTypeId = CMISBaseTypeDocument;
        } else if ([baseIdString isEqualToString:kCMISPropertyObjectTypeIdValueFolder]) {
            typeDef.baseTypeId = CMISBaseTypeFolder;
        }
        
        typeDef.creatable = [jsonDictionary[kCMISBrowserJSONCreateable] boolValue];
        typeDef.fileable = [jsonDictionary[kCMISBrowserJSONFileable] boolValue];
        typeDef.queryable = [jsonDictionary[kCMISBrowserJSONQueryable] boolValue];
        typeDef.fullTextIndexed = [jsonDictionary[kCMISBrowserJSONFullTextIndexed] boolValue];
        typeDef.includedInSupertypeQuery = [jsonDictionary[kCMISBrowserJSONIncludedInSuperTypeQuery] boolValue];
        typeDef.controllablePolicy = [jsonDictionary[kCMISBrowserJSONControllablePolicy] boolValue];
        typeDef.controllableAcl = [jsonDictionary[kCMISBrowserJSONControllableAcl] boolValue];
        
        NSDictionary *propertyDefinitions = jsonDictionary[kCMISBrowserJSONPropertyDefinitions];
        for (NSDictionary *propertyDictionary in [propertyDefinitions allValues]) {
            // create property definition and add to type definition
            CMISPropertyDefinition *propDef = [CMISPropertyDefinition new];
            propDef.id = propertyDictionary[kCMISBrowserJSONId];
            propDef.localName = propertyDictionary[kCMISBrowserJSONLocalName];
            propDef.localNamespace = propertyDictionary[kCMISBrowserJSONLocalNamespace];
            propDef.displayName = propertyDictionary[kCMISBrowserJSONDisplayName];
            propDef.queryName = propertyDictionary[kCMISBrowserJSONQueryName];
            propDef.description = propertyDictionary[kCMISBrowserJSONDescription];
            propDef.inherited = [propertyDictionary[kCMISBrowserJSONInherited] boolValue];
            propDef.required = [propertyDictionary[kCMISBrowserJSONRequired] boolValue];
            propDef.queryable = [propertyDictionary[kCMISBrowserJSONQueryable] boolValue];
            propDef.orderable = [propertyDictionary[kCMISBrowserJSONOrderable] boolValue];
            
            // determine property type
            NSString *typeString = propertyDictionary[kCMISBrowserJSONPropertyType];
            if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueString]) {
                propDef.propertyType = CMISPropertyTypeString;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueId]) {
                propDef.propertyType = CMISPropertyTypeId;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueInteger]) {
                propDef.propertyType = CMISPropertyTypeInteger;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueDecimal]) {
                propDef.propertyType = CMISPropertyTypeDecimal;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueBoolean]) {
                propDef.propertyType = CMISPropertyTypeBoolean;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueDateTime]) {
                propDef.propertyType = CMISPropertyTypeDateTime;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueHtml]) {
                propDef.propertyType = CMISPropertyTypeHtml;
            } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueUri]) {
                propDef.propertyType = CMISPropertyTypeUri;
            }
            
            // determine cardinality
            NSString *cardinalityString = propertyDictionary[kCMISBrowserJSONCardinality];
            if ([cardinalityString isEqualToString:kCMISBrowserJSONCardinalityValueSingle]) {
                propDef.cardinality = CMISCardinalitySingle;
            } else if ([cardinalityString isEqualToString:kCMISBrowserJSONCardinalityValueMultiple]) {
                propDef.cardinality = CMISCardinalityMulti;
            }
            
            // determine updatability
            NSString *updatabilityString = propertyDictionary[kCMISBrowserJSONUpdateability];
            if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueReadOnly]) {
                propDef.updatability = CMISUpdatabilityReadOnly;
            } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueReadWrite]) {
                propDef.updatability = CMISUpdatabilityReadWrite;
            } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueOnCreate]) {
                propDef.updatability = CMISUpdatabilityOnCreate;
            } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueWhenCheckedOut]) {
                propDef.updatability = CMISUpdatabilityWhenCheckedOut;
            }
            
            // TODO: look for restricted choices
            propDef.openChoice = YES;
            
            [typeDef addPropertyDefinition:propDef];
        }
    }
    
    return typeDef;
}

+ (CMISObjectData *)objectDataFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil

    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISObjectData *objectData = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectData object
        objectData = [CMISBrowserUtil objectDataFromDictionary:jsonDictionary];
    }
    
    return objectData;
}

+ (CMISObjectList *)objectListFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISObjectList *objectList = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectList object
        objectList = [CMISObjectList new];
        
        // parse the objects
        NSArray *objectsArray = jsonDictionary[@"objects"];
        if (objectsArray) {
            NSMutableArray *objects = [NSMutableArray arrayWithCapacity:objectsArray.count];
            for (NSDictionary *dictionary in objectsArray) {
                NSDictionary *objectDictionary = dictionary[@"object"];
                CMISObjectData *objectData = [CMISBrowserUtil objectDataFromDictionary:objectDictionary];
                [objects addObject:objectData];
            }
            
            // pass objects to list
            objectList.objects = objects;
        }
        
        // retrieve the paging data
        objectList.hasMoreItems = [jsonDictionary[@"hasMoreItems"] boolValue];
        objectList.numItems = [jsonDictionary[@"numItems"] intValue];
    }
    
    return objectList;
}

#pragma mark -
#pragma mark Private helper methods

+ (CMISObjectData *)objectDataFromDictionary:(NSDictionary *)dictionary
{
    CMISObjectData *objectData = [CMISObjectData new];
    NSDictionary *propertiesJson = dictionary[@"succinctProperties"];
    objectData.identifier = propertiesJson[kCMISPropertyObjectId];
    
    // determine the object type
    NSString *baseType = propertiesJson[kCMISPropertyBaseTypeId];
    if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueDocument]) {
        objectData.baseType = CMISBaseTypeDocument;
    } else if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueFolder]) {
        objectData.baseType = CMISBaseTypeFolder;
    }
    
    // create properties
    CMISProperties *properties = [CMISProperties new];
    NSArray *propNames = [propertiesJson allKeys];
    for (NSString *propName in propNames) {
        CMISPropertyData *propertyData;
        id propValue = propertiesJson[propName];
        if ([propValue isKindOfClass:[NSArray class]]) {
            propertyData = [CMISPropertyData createPropertyForId:propName arrayValue:propValue type:CMISPropertyTypeString];
        }
        else {
            propertyData = [CMISPropertyData createPropertyForId:propName stringValue:propValue];
        }
        
        [properties addProperty:propertyData];
    }
    
    // set the properties
    objectData.properties = properties;
    
    return objectData;
}

@end
