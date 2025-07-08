# SwiftConversion

This folder contains utilities for visualizing the conversions dependencies of internal ObjC types. If an ObjC class has a function visible in it’s header that uses an internal type, that internal type must be converted to Swift first. This is because of our use of `@_implementationOnly`. Any time imported from ObjC (through `@_implementationOnly`) can only be used by the implementation of the Swift class, not by the interface of it.

The scripts in this directory run on each commit to `main` and give us a tree of dependencies. The root nodes can be converted to Swift, and the ones with the most children nodes will unlock the most additional Swift conversion.
