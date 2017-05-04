fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

## Choose your installation method:

<table width="100%" >
<tr>
<th width="33%"><a href="http://brew.sh">Homebrew</a></td>
<th width="33%">Installer Script</td>
<th width="33%">Rubygems</td>
</tr>
<tr>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS or Linux with Ruby 2.0.0 or above</td>
</tr>
<tr>
<td width="33%"><code>brew cask install fastlane</code></td>
<td width="33%"><a href="https://download.fastlane.tools">Download the zip file</a>. Then double click on the <code>install</code> script (or run it in a terminal window).</td>
<td width="33%"><code>sudo gem install fastlane -NV</code></td>
</tr>
</table>

# Available Actions
### test
```
fastlane test
```
Test iOS, tvOS, and OSX
### localcoverage
```
fastlane localcoverage
```

### lint
```
fastlane lint
```

### test_swift_2_ios
```
fastlane test_swift_2_ios
```

### test_swift_2_tvos
```
fastlane test_swift_2_tvos
```

### test_swift_2_macos
```
fastlane test_swift_2_macos
```

### test_swift_3_tvos
```
fastlane test_swift_3_tvos
```

### test_swift_3_macos
```
fastlane test_swift_3_macos
```

### test_swift_3_ios
```
fastlane test_swift_3_ios
```

### travis_slather
```
fastlane travis_slather
```

### do_carthage
```
fastlane do_carthage
```

### reset_carthage
```
fastlane reset_carthage
```

### build_carthage
```
fastlane build_carthage
```

### test_carthage
```
fastlane test_carthage
```

### do_cocoapods
```
fastlane do_cocoapods
```

### reset_cocoapods
```
fastlane reset_cocoapods
```

### build_cocoapods
```
fastlane build_cocoapods
```

### test_cocoapods
```
fastlane test_cocoapods
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
