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
#import "CMISRenditionData.h"
#import "CMISDocumentTypeDefinition.h"
#import "CMISFolderTypeDefinition.h"
#import "CMISRelationshipTypeDefinition.h"
#import "CMISItemTypeDefinition.h"
#import "CMISSecondaryTypeDefinition.h"
#import "CMISErrors.h"

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
            repoInfo.vendorName = repo[kCMISBrowserJSONVendorName];
            repoInfo.productName = repo[kCMISBrowserJSONProductName];
            repoInfo.productVersion = repo[kCMISBrowserJSONProductVersion];
            repoInfo.rootFolderId = repo[kCMISBrowserJSONRootFolderId];
            repoInfo.repositoryUrl = repo[kCMISBrowserJSONRepositoryUrl];
            repoInfo.rootFolderUrl = repo[kCMISBrowserJSONRootFolderUrl];
            
            repoInfo.repositoryCapabilities = repo[kCMISBrowserJSONCapabilities]; //TODO should be own type instead of dictionary
            //TOOD aclCapabilities
            repoInfo.latestChangeLogToken = repo[kCMISBrowserJSONLatestChangeLogToken];
            
            repoInfo.cmisVersionSupported = repo[kCMISBrowserJSONCMISVersionSupported];
            repoInfo.thinClientUri = repo[kCMISBrowserJSONThinClientUri];

            //TODO repoInfo.changesIncomplete = repo[kCMISBrowserJSONChangesIncomplete];
            //TODO changesOnType

            repoInfo.principalIdAnonymous = repo[kCMISBrowserJSONPrincipalIdAnonymous];
            repoInfo.principalIdAnyone = repo[kCMISBrowserJSONPrincipalIdAnyone];
            
            //handle extensions
            repoInfo.extensions = [CMISBrowserUtil convertExtensions:repo cmisKeys:[CMISBrowserConstants repositoryInfoKeys]];
            
            // store the repo and root folder URLs in the session (when the repoId matches)
            if ([repoInfo.identifier isEqualToString:bindingSession.repositoryId]) {
                [bindingSession setObject:repoInfo.rootFolderUrl forKey:kCMISBrowserBindingSessionKeyRootFolderUrl];
                [bindingSession setObject:repoInfo.repositoryUrl forKey:kCMISBrowserBindingSessionKeyRepositoryUrl];
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
        //TODO check for valid baseTypeId (cmis:document, cmis:folder, cmis:relationship, cmis:policy, [cmis:item, cmis:secondary])
        CMISBaseType baseType = [CMISEnums enumForBaseId:jsonDictionary[kCMISBrowserJSONBaseId]];
        switch (baseType) {
            case CMISBaseTypeDocument:
                typeDef = [CMISDocumentTypeDefinition new];
                ((CMISDocumentTypeDefinition*)typeDef).contentStreamAllowed = [CMISEnums enumForContentStreamAllowed:jsonDictionary[kCMISBrowserJSONContentStreamAllowed]];
                ((CMISDocumentTypeDefinition*)typeDef).versionable = [jsonDictionary[kCMISBrowserJSONVersionable] boolValue];
                break;
            case CMISBaseTypeFolder:
                typeDef = [CMISFolderTypeDefinition new];
                break;
                
            case CMISBaseTypeRelationship: {
                typeDef = [CMISRelationshipTypeDefinition new];
                
                id allowedSourceTypes = jsonDictionary[kCMISBrowserJSONAllowedSourceTypes];
                if([allowedSourceTypes isKindOfClass:NSArray.class]){
                    NSMutableArray *types = [[NSMutableArray alloc] init];
                    for (id type in allowedSourceTypes) {
                        if(type){
                            [types addObject:type];
                        }
                    }
                    ((CMISRelationshipTypeDefinition*)typeDef).allowedSourceTypes = types;
                }
                
                id allowedTargetTypes = jsonDictionary[kCMISBrowserJSONAllowedTargetTypes];
                if([allowedTargetTypes isKindOfClass:NSArray.class]){
                    NSMutableArray *types = [[NSMutableArray alloc] init];
                    for (id type in allowedTargetTypes) {
                        if(type){
                            [types addObject:type];
                        }
                    }
                    ((CMISRelationshipTypeDefinition*)typeDef).allowedTargetTypes = types;
                }
                break;
            }
            case CMISBaseTypeItem:
                typeDef = [CMISItemTypeDefinition new];
                break;
            case CMISBaseTypeSecondary:
                typeDef = [CMISSecondaryTypeDefinition new];
                break;
            default:
                if (outError != NULL) *outError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:[NSString stringWithFormat:@"Type '%@' does not match a base type!", jsonDictionary[kCMISBrowserJSONBaseId]]];
                return nil;
        }

        typeDef.baseTypeId = baseType;
        typeDef.description = jsonDictionary[kCMISBrowserJSONDescription];
        typeDef.displayName = jsonDictionary[kCMISBrowserJSONDisplayName];
        typeDef.id = jsonDictionary[kCMISBrowserJSONId];
        typeDef.controllablePolicy = [jsonDictionary[kCMISBrowserJSONControllablePolicy] boolValue];
        typeDef.controllableAcl = [jsonDictionary[kCMISBrowserJSONControllableAcl] boolValue];
        typeDef.creatable = [jsonDictionary[kCMISBrowserJSONCreateable] boolValue];
        typeDef.fileable = [jsonDictionary[kCMISBrowserJSONFileable] boolValue];
        typeDef.fullTextIndexed = [jsonDictionary[kCMISBrowserJSONFullTextIndexed] boolValue];
        typeDef.includedInSupertypeQuery = [jsonDictionary[kCMISBrowserJSONIncludedInSuperTypeQuery] boolValue];
        typeDef.queryable = [jsonDictionary[kCMISBrowserJSONQueryable] boolValue];
        typeDef.localName = jsonDictionary[kCMISBrowserJSONLocalName];
        typeDef.localNameSpace = jsonDictionary[kCMISBrowserJSONLocalNamespace];
        typeDef.parentTypeId = jsonDictionary[kCMISBrowserJSONParentId];
        typeDef.queryName = jsonDictionary[kCMISBrowserJSONQueryName];
        
        //TODO type mutability
        
        NSDictionary *propertyDefinitions = jsonDictionary[kCMISBrowserJSONPropertyDefinitions];
        for (NSDictionary *propertyDefDictionary in [propertyDefinitions allValues]) {
            [typeDef addPropertyDefinition:[CMISBrowserUtil convertPropertyDefinition:propertyDefDictionary]];
        }
        
        // handle extensions
        typeDef.extensions = [CMISBrowserUtil convertExtensions:jsonDictionary cmisKeys:[CMISBrowserConstants typeKeys]];
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
        objectData = [CMISBrowserUtil convertObject:jsonDictionary];
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
        NSArray *objectsArray;
        if([jsonDictionary isKindOfClass:NSArray.class]){ // is NSArray
            objectsArray = jsonDictionary;
            
            objectList.hasMoreItems = NO;
            objectList.numItems = (int)objectsArray.count;
        } else { // is NSDictionary
            objectsArray = jsonDictionary[kCMISBrowserJSONObjects];
            
            // retrieve the paging data
            objectList.hasMoreItems = [jsonDictionary[kCMISBrowserJSONHasMoreItems] boolValue];
            objectList.numItems = [jsonDictionary[kCMISBrowserJSONNumberItems] intValue];
        }
        if (objectsArray) {
            NSMutableArray *objects = [NSMutableArray arrayWithCapacity:objectsArray.count];
            for (NSDictionary *dictionary in objectsArray) {
                NSDictionary *objectDictionary = dictionary[kCMISBrowserJSONObject];
                if(!objectDictionary) {
                    objectDictionary = dictionary;
                }
                CMISObjectData *objectData = [CMISBrowserUtil convertObject:objectDictionary];
                if(objectData){
                    [objects addObject:objectData];
                }
            }
            
            // pass objects to list
            objectList.objects = objects;
        }
    }
    
    return objectList;
}

+ (NSArray *)renditionsFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    NSArray *renditions = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectData object
        renditions = [CMISBrowserUtil renditionsFromArray:jsonDictionary];
    }
    
    return renditions;
}

#pragma mark -
#pragma mark Private helper methods

+ (CMISObjectData *)convertObject:(NSDictionary *)dictionary
{
    if(!dictionary) {
        return nil;
    }
    
    CMISObjectData *objectData = [CMISObjectData new];
    NSDictionary *propertiesJson = dictionary[kCMISBrowserJSONSuccinctProperties];
    objectData.identifier = propertiesJson[kCMISPropertyObjectId];
    
    // determine the object type
    NSString *baseType = propertiesJson[kCMISPropertyBaseTypeId];
    if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueDocument]) {
        objectData.baseType = CMISBaseTypeDocument;
    } else if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueFolder]) {
        objectData.baseType = CMISBaseTypeFolder;
    }
    
    // set the properties
    NSDictionary *propertiesExtension = dictionary[kCMISBrowserJSONPropertiesExtension];
    objectData.properties = [CMISBrowserUtil convertSuccinctProperties:propertiesJson propertiesExtension:propertiesExtension];
    
    // relationships
    NSArray *relationshipsJson = dictionary[kCMISBrowserJSONRelationships];
    objectData.relationships = [CMISBrowserUtil convertObjects:relationshipsJson];
    
    //renditions
    NSArray *renditionsJson = dictionary[kCMISBrowserJSONRenditions];
    objectData.renditions = [self renditionsFromArray:renditionsJson];
    
    // handle extensions
    objectData.extensions = [CMISBrowserUtil convertExtensions:dictionary cmisKeys:[CMISBrowserConstants objectKeys]];
    
    return objectData;
}

+ (NSArray *)convertObjects:(NSArray *)json
{
    if (!json){
        return nil;
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (id obj in json) {
        //TODO check if obj is NSDictionary or else abort with error
        CMISObjectData *relationship = [CMISBrowserUtil convertObject:obj];
        if(relationship){
            [result addObject:relationship];
        }
    }
    
    return result;
}

+ (CMISProperties *)convertSuccinctProperties:(NSDictionary *)propertiesJson propertiesExtension:(NSDictionary *)extJson
{
    if(!propertiesJson) {
        return nil;
    }
    
    // TODO convert properties according to typeDefinition
    
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
    
    if(extJson){
        properties.extensions = [CMISBrowserUtil convertExtensions:extJson cmisKeys:[NSSet set]];
    }
    
    return properties;
}

+ (NSArray *)renditionsFromArray:(NSArray *)array
{
    if(!array) {
        return nil;
    }
    NSMutableArray *renditions = [[NSMutableArray alloc] initWithCapacity:array.count];
    for(NSDictionary *renditionJson in array){
        CMISRenditionData *renditionData = [CMISRenditionData new];
        renditionData.height = [NSNumber numberWithLongLong:[renditionJson[kCMISBrowserJSONRenditionHeight] longLongValue]];
        renditionData.kind = renditionJson[kCMISBrowserJSONRenditionKind];
        renditionData.length = [NSNumber numberWithLongLong:[renditionJson[kCMISBrowserJSONRenditionLength] longLongValue]];
        renditionData.mimeType = renditionJson[kCMISBrowserJSONRenditionMimeType];
        renditionData.renditionDocumentId = renditionJson[kCMISBrowserJSONRenditionDocumentId];
        renditionData.streamId = renditionJson[kCMISBrowserJSONRenditionStreamId];
        renditionData.title = renditionJson[kCMISBrowserJSONRenditionTitle];
        renditionData.width = [NSNumber numberWithLongLong:[renditionJson[kCMISBrowserJSONRenditionWidth] longLongValue]];
        
        // handle extensions
        renditionData.extensions = [CMISBrowserUtil convertExtensions:renditionJson cmisKeys:[CMISBrowserConstants renditionKeys]];
        
        [renditions addObject:renditionData];
    }
    
    return renditions;
}

+ (CMISPropertyDefinition *)convertPropertyDefinition:(NSDictionary *)propertyDictionary
{
    if(!propertyDictionary){
        return nil;
    }
    
    // create property definition and add to type definition
    CMISPropertyDefinition *propDef = [CMISPropertyDefinition new];
    propDef.id = propertyDictionary[kCMISBrowserJSONId];
    propDef.localName = propertyDictionary[kCMISBrowserJSONLocalName];
    propDef.localNamespace = propertyDictionary[kCMISBrowserJSONLocalNamespace];
    propDef.queryName = propertyDictionary[kCMISBrowserJSONQueryName];
    propDef.description = propertyDictionary[kCMISBrowserJSONDescription];
    propDef.displayName = propertyDictionary[kCMISBrowserJSONDisplayName];
    propDef.inherited = [propertyDictionary[kCMISBrowserJSONInherited] boolValue];
    propDef.openChoice = [propertyDictionary[kCMISBrowserJSONOpenChoice] boolValue];
    propDef.orderable = [propertyDictionary[kCMISBrowserJSONOrderable] boolValue];
    propDef.queryable = [propertyDictionary[kCMISBrowserJSONQueryable] boolValue];
    propDef.required = [propertyDictionary[kCMISBrowserJSONRequired] boolValue];
    
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
    
    // TODO default value
    
    // handle extensions
    propDef.extensions = [CMISBrowserUtil convertExtensions:propertyDictionary cmisKeys:[CMISBrowserConstants propertyTypeKeys]];
    
    return propDef;
}

+ (NSArray *)convertExtensions:(NSDictionary *)source cmisKeys:(NSSet *)cmisKeys
{
    if (!source) {
        return nil;
    }
    
    NSMutableArray *extensions = nil; // array of CMISExtensionElement's
    
    for (NSString *key in source.keyEnumerator) {
        if ([cmisKeys containsObject:key]) {
            continue;
        }
        
        if (!extensions) {
            extensions = [[NSMutableArray alloc] init];
        }
        
        id value = source[key];
        if ([value isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:value]]];
        } else if ([value isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:value]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:value]];
        }
    }
    return extensions;
}

+ (NSArray *)convertExtension:(NSDictionary *)dictionary
{
    if (!dictionary) {
        return nil;
    }
    
    NSMutableArray *extensions = [[NSMutableArray alloc] init]; // array of CMISExtensionElement's
    
    for (NSString *key in dictionary.keyEnumerator) {
        id value = dictionary[key];
        if ([value isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:value]]];
        } else if ([value isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:value]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:value]];
        }
    }
    
    return extensions;
}

+ (NSArray *)convertExtension:(NSString *)key fromArray:(NSArray *)array
{
    if (!array) {
        return nil;
    }
    
    NSMutableArray *extensions = [[NSMutableArray alloc] init]; // array of CMISExtensionElement's
    
    for (id element in array) {
        if ([element isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:element]]];
        } else if ([element isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:element]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:element]];
        }
    }
    
    return extensions;
}

@end
