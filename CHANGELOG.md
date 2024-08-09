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