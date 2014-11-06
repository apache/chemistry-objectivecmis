#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BUILD_UNIVERSAL_LIB='TRUE'
export BUILD_UNIVERSAL_LIB

if [[ "$1" == "Debug" ]] ; then
   BUILD_CONFIG=Debug
   echo "Building debug version of libraries..."
else
   BUILD_CONFIG=Release
   echo "Building release version of libraries..."
fi

xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS-iOS -configuration $BUILD_CONFIG ONLY_ACTIVE_ARCH=NO clean build
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS-OSX -configuration $BUILD_CONFIG ONLY_ACTIVE_ARCH=NO clean build

appledoc --project-name ObjectiveCMIS --project-company "Apache Chemistry" --company-id org.apache.chemistry --output ./ObjectiveCMISHelp --keep-intermediate-files --exit-threshold 2 --keep-undocumented-objects --keep-undocumented-members --ignore .m --ignore ObjectiveCMISTests --ignore build .

