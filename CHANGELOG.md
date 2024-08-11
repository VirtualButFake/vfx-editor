# 1.0.8
Changes
- Fix issue with breadcrumb in texture storage not working correctly with <2 labels
- Fix Texture path breaking and resulting in a crash
- Made it so that clicking a texture that is set and found will now open the folder it is in
- Fix bug where creating a folder would empty the texture storage

# 1.0.7
Changes
- NumberSequence buttons now feature an input box alongside the graph button, to set a constant value.
- A graph will now adjust itself to the max value in the sequence, if this is higher than the max size setting.
- Decals are now taken into account with "Import Instances"

# 1.0.6
Changes
- Update `fusionComponents` to fix potential recursive state error
- `TexturePicker` now uses a different list format to prevent state updates causing unecessary rerenders

# 1.0.5
Changes
- Bump `themeFramework` and `fusionComponents` for more extensible appearance modification support.
- `Emit Delay` and `Emit Count` will now look for existing attributes in order to make migration easier

Fixes
- Experimental fix for crashing when interacting with property fields in a certain way
- Fixed `Flipbook` image preview race condition

# 1.0.4
Changes
- Bump `themeFramework` and `fusionComponents` for better typing of `useColorFunction`

# 1.0.3
Fixes
- Fixed memory leak in `CanvasFrame` and `StandaloneScroller` that caused instances to stay in memory even post-destruction. Memory issues should be significantly alleviated, but there are still some issues. This will be addressed in a future release.

# 1.0.2
Fixes
- Add a stroke around `TimelineButton`s in `ColorSequenceEditor` to provide sufficient contrast in light mode

# 1.0.1
Fixes
- Wrapped base instance creation in `historyHandler` to allow for undo/redo on first change

# 1.0.0
- Initial release