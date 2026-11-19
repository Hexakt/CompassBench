"""Génère un projet Xcode déterministe, sans outil ni paquet téléchargé.

Adapté de SmokeSignalIOS/scripts/generate-project.py.
Usage : python3 scripts/generate-project.py         (écrit le projet)
        python3 scripts/generate-project.py --check (vérifie qu'il est à jour)
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
NAME = 'CompassBench'
BUNDLE_ID = 'fr.paperbolt.compassbench'


def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def q(value):
    return json.dumps(str(value), ensure_ascii=False)


def generate():
    objects = []

    def add(key, body):
        objects.append(f'\t\t{uid(key)} = {{{body}}};')
        return uid(key)

    def ref(path, kind):
        return add('file:' + path, f'isa = PBXFileReference; lastKnownFileType = {q(kind)}; path = {q(path)}; sourceTree = "<group>"; ')

    def build(path, file_id):
        return add('build:' + path, f'isa = PBXBuildFile; fileRef = {file_id}; ')

    files, sources = [], []
    for path in sorted((ROOT / NAME).rglob('*.swift'), key=lambda p: p.as_posix()):
        relative = path.relative_to(ROOT / NAME).as_posix()
        file_id = ref(relative, 'sourcecode.swift')
        files.append(file_id)
        sources.append(build(relative, file_id))
    files.append(ref('Info.plist', 'text.plist.xml'))
    product = add('product', f'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; ')
    app_group = add('appGroup', f'isa = PBXGroup; children = ({",".join(files)}); path = {NAME}; sourceTree = "<group>"; ')
    products = add('products', f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>"; ')
    main_group = add('mainGroup', f'isa = PBXGroup; children = ({app_group},{products}); sourceTree = "<group>"; ')
    for key, kind, entries in [('sources', 'PBXSourcesBuildPhase', sources), ('resources', 'PBXResourcesBuildPhase', []), ('frameworks', 'PBXFrameworksBuildPhase', [])]:
        add(key, f'isa = {kind}; buildActionMask = 2147483647; files = ({",".join(entries)}); runOnlyForDeploymentPostprocessing = 0; ')

    for scope in ['project', 'target']:
        configs = []
        for mode in ['Debug', 'Release']:
            settings = {
                'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
                'SWIFT_VERSION': '5.0', 'CLANG_ENABLE_MODULES': 'YES',
                'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
                'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym',
                'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if mode == 'Debug' else '',
            }
            if scope == 'target':
                settings.update({
                    'PRODUCT_NAME': NAME, 'PRODUCT_BUNDLE_IDENTIFIER': BUNDLE_ID,
                    'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
                    'INFOPLIST_FILE': f'{NAME}/Info.plist', 'CODE_SIGN_STYLE': 'Automatic',
                    'DEVELOPMENT_TEAM': '', 'GENERATE_INFOPLIST_FILE': 'NO',
                    'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
                    'ENABLE_PREVIEWS': 'YES', 'ENABLE_TESTABILITY': 'YES' if mode == 'Debug' else 'NO',
                })
            values = ''.join(f'{k} = {q(v)};' for k, v in settings.items())
            configs.append(add(scope + mode, f'isa = XCBuildConfiguration; buildSettings = {{{values}}}; name = {mode}; '))
        add(scope + 'Configurations', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; ')
    target = add('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetConfigurations")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = {NAME}; productName = {NAME}; productReference = {product}; productType = "com.apple.product-type.application"; ')
    project = add('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{{target} = {{CreatedOnToolsVersion = 16.0;}};}};}}; buildConfigurationList = {uid("projectConfigurations")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = fr; hasScannedForEncodings = 0; knownRegions = (fr,en,Base); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target}); ')
    pbx = '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {project};\n}}\n'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{NAME}.app" BlueprintName="{NAME}" ReferencedContainer="container:{NAME}.xcodeproj"/>
  </BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{NAME}.app" BlueprintName="{NAME}" ReferencedContainer="container:{NAME}.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    for relative, data in [(f'{NAME}.xcodeproj/project.pbxproj', pbx), (f'{NAME}.xcodeproj/xcshareddata/xcschemes/{NAME}.xcscheme', scheme)]:
        path = ROOT / relative
        if '--check' in sys.argv:
            if not path.exists() or path.read_text(encoding='utf-8') != data:
                raise SystemExit('Projet Xcode pas à jour : ' + relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data, encoding='utf-8', newline='\n')
    print('Projet Xcode à jour.' if '--check' in sys.argv else 'Projet Xcode généré.')


if __name__ == '__main__':
    generate()
