# Ice

The package manager Swift deserves. 100% compatible with Swift Package Manager

### Motivation

The official [Swift Package Manager](https://github.com/apple/swift-package-manager) is great at actually managing packages (resolving package versions, compiling source, etc.), but it lacks in developer friendliness. Ice uses Swift Package Manger in its core, but provides a much more developer friendly layer on top of SPM.

A few features Ice has that SPM lacks:
- Beautiful, yet information dense output (particularly while building and testing)
- Imperatively manage `Package.swift` (e.g. `ice add RxSwift`)
- A centralized registry of packages
- Short command names for the most used commands
- Automatic rebuilding / restarting an app upon source changes

## Prettified output

### Init
![new](https://github.com/jakeheis/Ice/raw/gifs/new.gif)

### Build
![build](https://github.com/jakeheis/Ice/raw/gifs/build.gif)

### Test
![test](https://github.com/jakeheis/Ice/raw/gifs/test.gif)

## Imperatively manage `Package.swift`

Manage dependencies:

```shell
ice add RxSwift
ice add Alamofire 4.5.1
ice add jakeheis/SwiftCLI
ice remove Alamofire
```

Manage targets:

```shell
ice target add Core
ice target add --test CoreTests
ice target depend CoreTests Core
ice target remove CoreTests
```

## Centralized package registry

The built in registry (https://github.com/jakeheis/IceRegistry) consists of the most-starred Swift repositories on Github. You get these for free, but you can also create your own personal entries to a local registry:

```shell
> ice registry lookup Alamofire
https://github.com/Alamofire/Alamofire
> ice registry lookup SwiftCLI

Error: couldn't find SwiftCLI

> ice registry add https://github.com/jakeheis/SwiftCLI SwiftCLI
> ice add SwiftCLI
> ice registry remove SwiftCLI
```

## Automatic rebuilding / restarting

`ice build` and `ice run` both accept a watch flag which instructs them to rebuild/restart your app whenever a source file changes:

```shell
> ice build -w
[ice] rebuilding due to changes...
Compile CLI (20 sources)

  ● Error: use of unresolved identifier 'dsf'

    dsf
    ^^^
    at Sources/CLI/Target.swift:74

[ice] rebuilding due to changes...
Compile CLI (20 sources)
Link ./.build/x86_64-apple-macosx10.10/debug/ice
```

```shell
> ice run -w
[ice] restarting due to changes...
```

## Other commands

```shell
> ice clean
> ice reset
> ice init
> ice config set <key> <value>
> ice dump
> ice describe SwiftCLI
> ice search CLI

# Generate an Xcode project
> ice xc
generated: ./Ice.xcodeproj

# Rebuild every time a source file changes
> 
```

### FAQ

#### Why does Ice internally use Swift Package Manager at all? Why not write an entirely new package manager?

A goal of Ice is to retain 100% compatibilty with SPM -- the goal is not to splinter the ecosystem in any way. By building Ice on top of SPM, we can easily attain that goal.

#### Why not contribute these improvements directly to SPM rather than creating a new layer on top of it?

Swift Package Manager has considered some of the improvements offered in Ice but rejected them (for now). Notably, SPM chose to keep the package manager within the `swift` executable, meaning that commands are often quite verbose. I believe that tasks as common as cleaning a package should not require the user to type commands as lengthy as `swift package clean`.

Having said that, it's my hope that Ice can be a proving ground for some of these features, a place where they can be fine-tuned and eventually can make their way into SPM core. Ideally, Ice will one day be unnecessary.
