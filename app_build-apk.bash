#!/bin/bash

### android
### 从 pubspec.yaml 获取版本
VERSION=$(grep 'version:' pubspec.yaml | head -1 | sed 's/version: //' | tr -d ' ')
### 大版本号
VERSION_NAME=$(echo $VERSION | cut -d'+' -f1)
### --build-number: 内部构建编号 (如: 123)
BUILD_NUMBER=$(echo $VERSION | cut -d'+' -f2)
###
BUILD_DATE=$(date +%Y%m%d_%H_%M)

sleep 6

flutter build apk \
--obfuscate --split-per-abi \
--split-debug-info=build \
--release --build-name=$VERSION_NAME  --build-number=$BUILD_NUMBER -v

echo "Android 版本: $VERSION_NAME (构建于: $BUILD_DATE)"
