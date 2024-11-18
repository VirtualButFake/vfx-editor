<div align="center">

# VFX Editor

An all-in-one tool for creating visual effects on Roblox.

[![License](https://img.shields.io/github/license/virtualbutfake/vfx-editor?style=flat)](https://github.com/virtualbutfake/vfx-editor/blob/master/LICENSE.md)
[![CI](https://github.com/virtualbutfake/vfx-editor/actions/workflows/ci.yaml/badge.svg)](https://github.com/virtualbutfake/vfx-editor/actions)

</div>

## Features

This plugin replaces and revamps the functionality of features that previously required multiple plugins to achieve. It includes:

- A custom number sequence editor, supporting a wide range of easing styles and full Bezier curve support.
- A color sequence editor
- A texture storage system, which simulates a custom file system for textures, with full flipbook support.
- Comprehensive support for every relevant property, allowing you to replace multiple plugins and the default Roblox properties window with a single, all-encompassing tool.
- Full support for undo/redo on almost every action.
- Full theme support, with both a default light and dark theme.
- A lightweight mode, offering a stripped-down version of the plugin that includes only the most essential features, designed to mimic the original properties window for a minimal learning curve.

## Getting Started

To get started, you can either get the plugin on the Roblox Marketplace [here](https://create.roblox.com/store/asset/18800449515) for automatic updates, build the plugin yourself or grab it from GitHub releases.

## Installing via GitHub releases
1. Click the latest release under "Releases"
2. Download the "build.rbxm" file
3. Open your Plugins folder (if you are not sure where this is, open Studio, navigate to the Plugins tab and click the "Plugins Folder" button)
4. Drag "build.rbxm" into this folder and restart Studio

## Building

### Prerequisites

To build the plugin, you will need [Aftman](https://github.com/LPGhatguy/aftman), a toolchain manager.

### Instructions

To build the plugin, clone the repository and run the following commands:

```bash
aftman install
lune run build
```

Then place the `build.rbxm` file in your Roblox plugins folder and restart Roblox Studio.

## Wiki

For more information on how to use the plugin, please refer to the [wiki](https://github.com/VirtualButFake/vfx-editor/wiki)

## Contributing

Contributions are always welcomed. Code should follow Stylua and Selene formatting conventions. To contribute, fork this repository, make your changes, and create a pull request. Please make sure to test your changes before creating a pull request.

In order to run the stories to test your code, place a .luau file with the following code in your plugins folder:

```luau
plugin.Name = "plugin"
```

and make sure that `Plugin Debugging` is enabled in the Studio settings.
This will then allow the components to find a plugin when needed. [Flipbook](https://github.com/flipbook-labs/flipbook) is recommended as the storybook plugin.

This plugin is by no means perfect. If you find any bugs or have any suggestions, please create an issue.

## Changelog

For a full list of changes, please refer to the [changelog](CHANGELOG.md).

## License

This project is licensed under the MIT License - see the [LICENSE.md](https://github.com/virtualbutfake/vfx-editor/blob/main/LICENSE.md) file for details.
