# SkyWay iOS Sample
Sample application of SkyWayiOSSDK

## How to build
 1. Register an account on [SkyWay](http://nttcom.github.io/skyway/) and get an API key
 1. Clone or download this repository.
 1. Install SkyWay.framework with cocoapods
  1. Instruction is written in next section
 1. Open "SkyWay-iOS-Sample.xcworkspace"
 1. Set kAPIKey and kDomain to your API key/Domain registered on SkyWay.io at the top of "MediaConnectionViewController.m" then build!
```objective-c
// Enter your APIkey and Domain
// Please check this page. >> https://skyway.io/ds/
static NSString *const kAPIkey = @"";
static NSString *const kDomain = @"";
```

##Installation of SkyWay.framework with CocoaPods
Podfile

```
platform :ios, '7.0'
pod 'SkyWay-iOS-SDK'
```

Install
```
pod install
```

## NOTICE
This application requires v0.2.0+ of SkyWay iOS SDK.

------

## ビルド方法
 1. [SkyWay](http://nttcom.github.io/skyway/)でアカウントを作成し、APIkeyを取得
 1. このレポジトリをクローンまたはダウンロード
 1. "SkyWay.framework"をcocoapodsを用いプロジェクトにインストール
  1. cocoapodsについては、次のセクションを参照
 1. "SkyWay-iOS-Sample.xcworkspace"を開く
 1. "MediaConnectionViewController.m"の上部にあるkAPIKeyとkDomainにAPIkeyとDomainを入力し、ビルド

```objective-c
// Enter your APIkey and Domain
// Please check this page. >> https://skyway.io/ds/
static NSString *const kAPIkey = @"";
static NSString *const kDomain = @"";
```
##CocoaPodsを利用したSkyWay.frameworkのインストール
Podfile

```
platform :ios, '7.0'
pod 'SkyWay-iOS-SDK'
```

Install
```
pod install
```


## 注意事項
本アプリケーションはSkyWay iOS SDKのv0.2.0以降で動作します。
