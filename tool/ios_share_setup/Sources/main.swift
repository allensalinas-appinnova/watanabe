import Foundation
import XcodeProj
import PathKit

let path = Path(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ios/Runner.xcodeproj")
let xcode = try XcodeProj(path: path)
let pbx = xcode.pbxproj
let project = pbx.projects.first!
let runner = pbx.nativeTargets.first { $0.name == "Runner" }!
let name = "ShareExtension"
let groupID = "group.com.appinnova.lumiomoney.receipts"
let team = runner.buildConfigurationList!.buildConfigurations.first!.buildSettings["DEVELOPMENT_TEAM"]!
for config in runner.buildConfigurationList!.buildConfigurations {
  config.buildSettings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
  config.buildSettings["CUSTOM_GROUP_ID"] = groupID
}
if !pbx.nativeTargets.contains(where: { $0.name == name }) {
  let sources = PBXSourcesBuildPhase(); pbx.add(object: sources)
  let frameworks = PBXFrameworksBuildPhase(); pbx.add(object: frameworks)
  let product = PBXFileReference(sourceTree: .buildProductsDir, explicitFileType: "wrapper.app-extension", path: "ShareExtension.appex", includeInIndex: false)
  pbx.add(object: product); project.productsGroup!.children.append(product)
  var configs: [XCBuildConfiguration] = []
  for original in runner.buildConfigurationList!.buildConfigurations {
    let c = XCBuildConfiguration(name: original.name, buildSettings: [
      "PRODUCT_BUNDLE_IDENTIFIER": "com.appinnova.lumiomoney.app.ShareExtension",
      "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
      "DEVELOPMENT_TEAM": team, "CODE_SIGN_STYLE": "Automatic", "CODE_SIGN_ENTITLEMENTS": "ShareExtension/ShareExtension.entitlements",
      "INFOPLIST_FILE": "ShareExtension/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "CUSTOM_GROUP_ID": groupID,
      "CURRENT_PROJECT_VERSION": "$(FLUTTER_BUILD_NUMBER)", "MARKETING_VERSION": "$(FLUTTER_BUILD_NAME)",
      "SKIP_INSTALL": "YES", "TARGETED_DEVICE_FAMILY": "1,2", "APPLICATION_EXTENSION_API_ONLY": "YES",
      "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]])
    c.baseConfiguration = original.baseConfiguration
    pbx.add(object: c); configs.append(c)
  }
  let list = XCConfigurationList(buildConfigurations: configs, defaultConfigurationName: "Release"); pbx.add(object: list)
  let target = PBXNativeTarget(name: name, buildConfigurationList: list, buildPhases: [sources, frameworks], productName: name, product: product, productType: .appExtension)
  pbx.add(object: target); project.targets.append(target)
  let exclude = PBXFileSystemSynchronizedBuildFileExceptionSet(target: target, membershipExceptions: ["Info.plist", "ShareExtension.entitlements"], publicHeaders: nil, privateHeaders: nil, additionalCompilerFlagsByRelativePath: nil, attributesByRelativePath: nil)
  pbx.add(object: exclude)
  let group = PBXFileSystemSynchronizedRootGroup(sourceTree: .group, path: "ShareExtension", exceptions: [exclude]); pbx.add(object: group)
  project.mainGroup.children.append(group); target.fileSystemSynchronizedGroups = [group]
  // Link the same SPM plugin product as Runner, without introducing CocoaPods.
  let package = XCLocalSwiftPackageReference(relativePath: "Flutter/ephemeral/Packages/.packages/receive_sharing_intent-1.9.0")
  pbx.add(object: package); project.localPackages.append(package)
  let dependency = XCSwiftPackageProductDependency(productName: "receive-sharing-intent"); pbx.add(object: dependency)
  target.packageProductDependencies = [dependency]
  let link = PBXBuildFile(product: dependency); pbx.add(object: link); frameworks.files = [link]
  _ = try runner.addDependency(target: target)
  let embedFile = PBXBuildFile(file: product, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]]); pbx.add(object: embedFile)
  let embed = PBXCopyFilesBuildPhase(dstPath: "", dstSubfolderSpec: .plugins, name: "Embed App Extensions", files: [embedFile]); pbx.add(object: embed)
  let thinIndex = runner.buildPhases.firstIndex { ($0 as? PBXShellScriptBuildPhase)?.name == "Thin Binary" } ?? runner.buildPhases.count
  runner.buildPhases.insert(embed, at: thinIndex)
}

var writeQAScheme: (() throws -> Void)?
if CommandLine.arguments.contains("--qa-tests") {
  func qaTarget(_ name:String, productType:PBXProductType, bundle:String) -> PBXNativeTarget {
    if let existing = pbx.nativeTargets.first(where:{$0.name == name}) { return existing }
    let sources = PBXSourcesBuildPhase();pbx.add(object:sources)
    let frameworks = PBXFrameworksBuildPhase();pbx.add(object:frameworks)
    let product = PBXFileReference(sourceTree:.buildProductsDir,explicitFileType:productType == .application ? "wrapper.application" : "wrapper.cfbundle",path:name + (productType == .application ? ".app" : ".xctest"),includeInIndex:false)
    pbx.add(object:product);project.productsGroup!.children.append(product)
    let configs = runner.buildConfigurationList!.buildConfigurations.map { original -> XCBuildConfiguration in
      var settings:BuildSettings = ["PRODUCT_BUNDLE_IDENTIFIER":bundle,"PRODUCT_NAME":"$(TARGET_NAME)","SWIFT_VERSION":"5.0","IPHONEOS_DEPLOYMENT_TARGET":"15.0","GENERATE_INFOPLIST_FILE":"YES","CURRENT_PROJECT_VERSION":"1","MARKETING_VERSION":"1.0","TARGETED_DEVICE_FAMILY":"1,2","CODE_SIGN_STYLE":"Automatic","DEVELOPMENT_TEAM":team]
      if productType == .application { settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Lumio QA sender" }
      else { settings["TEST_TARGET_NAME"] = "QAShareSender" }
      let config = XCBuildConfiguration(name:original.name,buildSettings:settings);pbx.add(object:config);return config
    }
    let list = XCConfigurationList(buildConfigurations:configs,defaultConfigurationName:"Debug");pbx.add(object:list)
    let target = PBXNativeTarget(name:name,buildConfigurationList:list,buildPhases:[sources,frameworks],productName:name,product:product,productType:productType);pbx.add(object:target);project.targets.append(target)
    let group = PBXFileSystemSynchronizedRootGroup(sourceTree:.group,path:name);pbx.add(object:group);project.mainGroup.children.append(group);target.fileSystemSynchronizedGroups = [group]
    return target
  }
  let sender = qaTarget("QAShareSender",productType:.application,bundle:"co.appinnova.lumio.qa.sender")
  let tests = qaTarget("ReceiptShareUITests",productType:.uiTestBundle,bundle:"co.appinnova.lumio.qa.sharetests")
  for config in sender.buildConfigurationList!.buildConfigurations {
    config.buildSettings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  }
  for config in tests.buildConfigurationList!.buildConfigurations {
    config.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  }
  if tests.dependencies.isEmpty { _ = try tests.addDependency(target:sender) }
  writeQAScheme = {
  let scheme = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="\(sender.uuid)" BuildableName="QAShareSender.app" BlueprintName="QAShareSender" ReferencedContainer="container:Runner.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="\(tests.uuid)" BuildableName="ReceiptShareUITests.xctest" BlueprintName="ReceiptShareUITests" ReferencedContainer="container:Runner.xcodeproj"/></TestableReference></Testables><EnvironmentVariables><EnvironmentVariable key="QA_SHARE_EMAIL" value="$(QA_SHARE_EMAIL)" isEnabled="YES"/></EnvironmentVariables></TestAction>
</Scheme>
"""
  let schemeFolder = path + "xcshareddata/xcschemes"
  try schemeFolder.mkpath()
  try scheme.write(toFile:(schemeFolder + "ReceiptShareQA.xcscheme").string,atomically:true,encoding:.utf8)
  }
}
try xcode.write(path: path)
try writeQAScheme?()
print("ShareExtension target and App Group settings configured")
