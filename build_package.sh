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

PACKAGE_ZIP=ObjectiveCMIS.zip
PACKAGE_DIR=build/Package

echo "Preparing package folder structure..."

if [ -d $PACKAGE_DIR ]
then
  rm -R $PACKAGE_DIR
fi
mkdir -p $PACKAGE_DIR

cp NOTICE $PACKAGE_DIR
cp LICENSE $PACKAGE_DIR
cp README $PACKAGE_DIR

echo "Building static library..."

export BUILD_UNIVERSAL_LIB='TRUE'
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS -configuration Debug ONLY_ACTIVE_ARCH=NO clean build
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS -configuration Release clean build

cp -R build/Debug-universal/* $PACKAGE_DIR
cp build/Release-universal/*.a $PACKAGE_DIR

echo "Creating package..."

pushd $PACKAGE_DIR
jar cvf $PACKAGE_ZIP *
popd

echo "done!"

