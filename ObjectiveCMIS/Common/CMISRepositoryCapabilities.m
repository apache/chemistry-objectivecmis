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

#import "CMISRepositoryCapabilities.h"
#import "CMISConstants.h"
#import "CMISLog.h"

@implementation CMISRepositoryCapabilities

-(void) setCapability:(NSString*)capabilityKey value:(id)capabilityValue {
    if ([capabilityKey isEqualToString:kCMISRepositoryAllVersionsSearchable]) {
        self.allVersionsSearchable = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityACL]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityAcl = CMISCapabilityAclNone;
        } else if ([capabilityValue isEqualToString:@"discover"]) {
            self.capabilityAcl = CMISCapabilityAclDiscover;
        } else if ([capabilityValue isEqualToString:@"manage"]) {
            self.capabilityAcl = CMISCapabilityAclManage;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability ACL Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityChanges]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityChanges = CMISCapabilityChangesNone;
        } else if ([capabilityValue isEqualToString:@"objectidsonly"]) {
            self.capabilityChanges = CMISCapabilityChangesObjectIdsOnly;
        } else if ([capabilityValue isEqualToString:@"properties"]) {
            self.capabilityChanges = CMISCapabilityChangesProperties;
        } else if ([capabilityValue isEqualToString:@"all"]) {
            self.capabilityChanges = CMISCapabilityChangesAll;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability Changes Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityContentStreamUpdatability]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityContentStreamUpdates = CMISCapabilityContentStreamUpdatesNone;
        } else if ([capabilityValue isEqualToString:@"anytime"]) {
            self.capabilityContentStreamUpdates = CMISCapabilityContentStreamUpdatesAnytime;
        } else if ([capabilityValue isEqualToString:@"pwconly"]) {
            self.capabilityContentStreamUpdates = CMISCapabilityContentStreamUpdatesPwcOnly;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability Updatability Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityGetDescendants]) {
        self.supportsGetDescendants = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityGetFolderTree]) {
        self.supportsGetFolderTree = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityJoin]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityJoin = CMISCapabilityJoinNone;
        } else if ([capabilityValue isEqualToString:@"inneronly"]) {
            self.capabilityJoin = CMISCapabilityJoinInnerOnly;
        } else if ([capabilityValue isEqualToString:@"innerandouter"]) {
            self.capabilityJoin = CMISCapabilityJoinInnerAndOuter;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability Join Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityQuery]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityQuery = CMISCapabilityQueryNone;
        } else if ([capabilityValue isEqualToString:@"metadataonly"]) {
            self.capabilityQuery = CMISCapabilityQueryMetaDataOnly;
        } else if ([capabilityValue isEqualToString:@"fulltextonly"]) {
            self.capabilityQuery = CMISCapabilityQueryFullTextOnly;
        } else if ([capabilityValue isEqualToString:@"bothseparate"]) {
            self.capabilityQuery = CMISCapabilityQueryBothSeparate;
        } else if ([capabilityValue isEqualToString:@"bothcombined"]) {
            self.capabilityQuery = CMISCapabilityQueryBothCombined;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability Query Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityMultifiling]) {
        self.supportsMultifiling = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityOrderBy]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityOrderBy = CMISCapabilityOrderByNone;
        } else if ([capabilityValue isEqualToString:@"common"]) {
            self.capabilityOrderBy = CMISCapabilityOrderByCommon;
        } else if ([capabilityValue isEqualToString:@"custom"]) {
            self.capabilityOrderBy = CMISCapabilityOrderByCustom;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Capability Order By Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityPropertyTypes]) {
        if(capabilityValue) {
            self.creatablePropertyTypes = [[CMISCreatablePropertyTypes alloc] init];
            [self.creatablePropertyTypes setCreateablePropertyTypeFromDictionary:capabilityValue];
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityPWCSearchable]) {
        self.pwcSearchable = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityPWCUpdatable]) {
        self.pwcUpdatable = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityRenditions]) {
        if ([capabilityValue isEqualToString:@"none"]) {
            self.capabilityRendition = CMISCapabilityOrderByNone;
        } else if ([capabilityValue isEqualToString:@"read"]) {
            self.capabilityRendition = CMISCapabilityOrderByCommon;
        } else {
            CMISLogWarning(@"WARNING: Unknown Repository Renditions Value");
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityVersionSpecificFiling]) {
        self.supportsVersionSpecificFiling = [capabilityValue boolValue];
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityNewTypeSettableAttributes]) {
        if(capabilityValue) {
            self.typeSettableAttributes = [[CMISNewTypeSettableAttributes alloc] init];
            [self.typeSettableAttributes setNewTypeSettableAttributesFromDictionary:capabilityValue];
        }
    } else if ([capabilityKey isEqualToString:kCMISRepositoryCapabilityUnfiling]) {
        self.supportsUnfiling = [capabilityValue boolValue];
    } else {
        CMISLogWarning(@"WARNING: Unknown Repository Capability Key");
    }
}

@end
