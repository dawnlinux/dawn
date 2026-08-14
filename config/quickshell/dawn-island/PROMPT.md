You are an expert Linux desktop engineer specializing in **Quickshell, QML, Qt, Hyprland, Wayland, and desktop UI architecture**.

I want you to build a complete, production-quality **Dynamic Island / Notch-style desktop shell for Hyprland using Quickshell + QML**.

The reference I am trying to recreate is this video:

https://youtu.be/nKomstQedmE

The project should reproduce the **behavior, layout, visual polish, animations, interactions, and overall concept** of the Dynamic Island shown in that reference as closely as technically possible.

IMPORTANT:

- Do NOT just explain how to build it.
- Do NOT give me snippets and ask me to connect them.
- ACTUALLY create the complete project in my filesystem.
- Inspect my existing Hyprland/Quickshell configuration before modifying anything.
- Reuse existing configuration where appropriate.
- Keep the implementation modular and maintainable.
- After implementing each major component, test it.
- Fix errors yourself instead of stopping and asking me what to do.
- Do not replace working parts of my system unnecessarily.
- If something in the reference cannot be reproduced exactly because of Linux/Wayland/Quickshell limitations, implement the closest possible equivalent.

==================================================

1. BOOTSTRAP / QUICKSHELL INSTALLATION
   ==================================================

IMPORTANT: Quickshell is NOT currently installed on this machine.

Before creating any Quickshell configuration:

1. Inspect the system:

   - uname -a
   - Hyprland version
   - Wayland session
   - Qt version
   - installed Qt/QML packages
   - pacman packages related to Qt/QML
   - whether quickshell exists
   - whether Quickshell is available from the configured Arch repositories
   - whether an appropriate AUR package exists

2. Determine the correct and currently compatible way to install Quickshell on this Arch Linux system.

3. Prefer the official Arch package/repository when available.

4. If it is not available there, inspect the appropriate AUR option.

5. DO NOT install random packages from untrusted sources.

6. Before installing anything, explain briefly what you are going to install.

7. Install the required Quickshell package and dependencies.

8. Verify installation with the appropriate version/help command.

9. Determine the installed Quickshell API/version and use THAT API when writing the project.

10. Do not blindly use Quickshell examples from old tutorials or videos if they target a different API version.

11. Create a minimal test configuration first.

12. Launch the minimal configuration.

13. Verify that a basic QML/Quickshell window successfully appears on my Hyprland desktop.

14. If the test fails:

    - inspect the actual error
    - determine whether it is an API/version/dependency/configuration problem
    - fix it
    - rerun the test

15. ONLY after the minimal Quickshell test works should you begin building the Dynamic Island.

IMPORTANT:
Quickshell is a dependency of this project, not an assumption about my machine.

The project must be built against the Quickshell version actually installed on this machine.

================================================== 2. ENVIRONMENT
==============

Target environment:

- Arch Linux
- Hyprland
- Wayland
- Quickshell
- QML / Qt
- Neovim
- Kitty
- Waybar may currently exist, but this Dynamic Island should eventually be capable of replacing it.

First inspect:

- Hyprland version
- Quickshell version
- installed Qt/QML components
- existing ~/.config/hypr
- existing ~/.config/quickshell
- existing ~/.config/waybar
- available media/notification/brightness/volume utilities
- Hyprland IPC availability
- audio stack (PipeWire/WirePlumber)
- notification daemon
- clipboard manager
- network tools

Do not assume paths or installed packages. Inspect the machine first.

================================================== 3. CORE CONCEPT
===============

Build a centered top-of-screen Dynamic Island / notch.

It should normally appear as a compact black rounded pill/notch.

When an event occurs, the island should dynamically expand horizontally and/or vertically to display contextual information.

The island should feel like a native part of the desktop rather than a conventional status bar.

Think:

IDLE
↓
COMPACT NOTCH
↓
EVENT
↓
EXPAND
↓
DISPLAY INFORMATION
↓
ANIMATE BACK
↓
COMPACT NOTCH

The animations must feel extremely polished.

Avoid cheap/basic QML animations.

Use smooth spring-like motion where appropriate.

Transitions should have:

- easing
- opacity transitions
- scale transitions
- width/height transitions
- content transitions
- subtle blur/glass effects
- smooth state changes

================================================== 4. VISUAL DESIGN
================

The visual language should be:

- Apple-inspired
- premium
- dark
- glass-like
- rounded
- subtle
- modern
- minimal without being empty
- high attention to spacing and typography

The default island should resemble a physical notch.

Use:

- very dark background
- high border radius
- subtle transparency
- blur/frosted-glass effect where Quickshell supports it
- subtle border/highlight
- carefully tuned shadows
- clean typography
- strong visual hierarchy
- smooth animated resizing

Do NOT make it look like a generic Linux widget.

Avoid:

- excessive gradients
- excessive borders
- giant icons
- ugly default Qt controls
- excessive text
- clutter
- abrupt animations

The result should look like someone intentionally designed a premium desktop interface.

================================================== 5. ARCHITECTURE
===============

Create a clean architecture.

For example:

~/.config/quickshell/
shell.qml

```
components/
    DynamicIsland.qml
    IslandBackground.qml
    IslandContent.qml
    IslandIcon.qml
    IslandText.qml
    IslandAnimation.qml

modules/
    MediaModule.qml
    VolumeModule.qml
    BrightnessModule.qml
    NotificationModule.qml
    ClipboardModule.qml
    WorkspaceModule.qml
    NetworkModule.qml
    BatteryModule.qml
    ClockModule.qml

services/
    HyprlandService.qml
    MediaService.qml
    AudioService.qml
    NotificationService.qml
    BrightnessService.qml
    ClipboardService.qml
    NetworkService.qml

theme/
    Theme.qml
    Colors.qml
    Typography.qml
    Animations.qml
```

Adjust the structure if Quickshell's current architecture makes a better organization possible.

The important thing is separation between:

UI
STATE
SERVICES
THEME
HYPRLAND IPC

Do not put the entire application into one gigantic QML file.

================================================== 6. STATE MACHINE
================

Implement an explicit state-driven architecture.

The Dynamic Island should have states such as:

- idle
- media
- notification
- volume
- brightness
- workspace
- clipboard
- network
- battery
- recording
- expanded

Only one primary contextual state should normally be displayed at once.

Events should have priority.

For example:

notification arrives
→
notification state temporarily takes priority

volume changes
→
volume state

workspace changes
→
workspace state

media changes
→
media state

After the event timeout expires:

```
→
```

idle

Make these priorities configurable.

================================================== 7. HYPRLAND INTEGRATION
=======================

Integrate directly with Hyprland.

Use Hyprland IPC/events where appropriate.

Track:

- active workspace
- workspace changes
- active window
- fullscreen state
- special workspaces
- monitor changes
- keyboard layout if available

Workspace changes should produce a polished temporary island animation.

For example:

workspace switch
↓
island expands
↓
workspace icon/number appears
↓
content animates
↓
island contracts

Do not poll unnecessarily when event-based APIs are available.

================================================== 8. MEDIA PLAYER
===============

Integrate with the Linux media stack, preferably through MPRIS.

Display:

- album art when available
- song title
- artist
- playback state
- play/pause
- previous
- next
- progress if practical

When media starts playing:

compact island
↓
expand
↓
album art + title + controls
↓
remain visible for a configurable period
↓
return to compact state

When the user interacts with the media controls, make the interaction feel immediate.

Support common players through MPRIS rather than hardcoding Spotify.

================================================== 9. VOLUME
=========

Integrate with PipeWire/WirePlumber/PulseAudio compatibility as appropriate.

When volume changes:

expand the island.

Show:

speaker icon
volume percentage
visual volume indicator

Mute should have its own visual state.

Example:

volume changed
↓
black island expands
↓
speaker icon
↓
volume indicator
↓
percentage
↓
smoothly collapses

================================================== 10. BRIGHTNESS
==============

Detect the appropriate brightness control available on the system.

When brightness changes:

show:

brightness icon
brightness percentage
visual indicator

Animate the indicator smoothly.

Do not continuously poll if event-based monitoring is possible.

================================================== 11. NOTIFICATIONS
=================

Integrate with the existing notification system.

When a notification arrives:

expand the Dynamic Island.

Display:

- application icon
- application name
- notification title
- notification body

Use sensible truncation.

Long notifications should not destroy the layout.

The notification should animate into the island elegantly.

Support configurable display duration.

================================================== 12. CLIPBOARD
=============

Integrate with the user's clipboard manager if available.

When useful clipboard events occur, provide a contextual notification.

For example:

Copied

[content preview]

The preview should be sanitized/truncated appropriately.

Do not expose sensitive clipboard data unnecessarily.

================================================== 13. WORKSPACE INDICATOR
=======================

The island should act as an elegant workspace indicator.

When switching workspaces:

show something similar to:

```
◉  3
```

or an equivalent premium visual representation.

Animate between workspace numbers.

If Hyprland provides workspace names/icons, support them.

================================================== 14. TOP NOTCH MODE
==================

This is important.

The compact island should look like an actual notch.

The default shape should be approximately:

```
    ╭────────────────╮
    │                │
    ╰────────────────╯
```

But visually integrated with the top edge of the screen.

It should support:

- centered position
- configurable width
- configurable height
- configurable top margin
- configurable corner radius

The expanded island should grow smoothly from this shape.

The expansion should feel like the notch itself is transforming.

Do NOT simply display a separate popup underneath it.

================================================== 15. INTERACTION
===============

The island should be interactive.

Possible interactions:

LEFT CLICK

- open contextual/default action

RIGHT CLICK

- secondary action/context menu where appropriate

MOUSE HOVER

- optionally expand or reveal controls

MEDIA:

- click album art → media player
- play/pause
- previous
- next

VOLUME:

- click → audio controls

WORKSPACE:

- clicking workspace indicator can optionally open workspace overview

Keep interactions configurable.

================================================== 16. RESPONSIVENESS
==================

The UI must work on:

- laptop displays
- external monitors
- different resolutions
- different scaling factors

Do not hardcode absolute screen coordinates.

Use Quickshell's screen/window APIs correctly.

The island should appear on the appropriate monitor.

Support multi-monitor setups.

================================================== 17. PERFORMANCE
===============

This is a desktop shell component.

Performance matters.

Avoid:

- unnecessary polling
- constantly running animations
- excessive timers
- excessive process spawning
- expensive QML bindings
- unnecessary image processing

The island should consume very little CPU when idle.

Idle state should essentially be dormant except for necessary event listeners.

================================================== 18. THEME SYSTEM
================

Create a centralized theme.

I want to be able to change the entire visual system from one place.

Include variables for:

background
foreground
secondaryText
accent
border
shadow
blur
radius
spacing
fontFamily
fontSize
animationDuration
springStrength

Do not scatter colors throughout QML files.

================================================== 19. ANIMATION SYSTEM
====================

Create reusable animation definitions.

Animations should include:

- island expansion
- island contraction
- fade in
- fade out
- scale
- content replacement
- icon replacement
- progress changes
- notification entry
- notification exit

Prefer physically pleasing spring-like motion where appropriate.

The island should never feel robotic.

================================================== 20. WALLPAPER / COLOR INTEGRATION
=================================

If practical, create a centralized accent-color system that can eventually derive an accent from the current wallpaper.

Do not make this a hard dependency.

The Dynamic Island should work perfectly without wallpaper extraction.

================================================== 21. WAYBAR REPLACEMENT
======================

Eventually I want to be able to remove Waybar completely.

Therefore the Dynamic Island should eventually cover useful functionality such as:

- workspace state
- clock
- battery
- network
- volume
- brightness
- media
- notifications

However, do not overcrowd the island.

The point is contextual information rather than permanently showing every status.

================================================== 22. CLOCK / BATTERY / NETWORK
=============================

Implement compact contextual versions of:

CLOCK
BATTERY
NETWORK

These should not permanently clutter the island.

They can appear through:

- hover
- click
- relevant state
- configurable behavior

================================================== 23. CONFIGURATION
=================

Make configuration easy.

Provide a configuration file with options such as:

islandWidth
islandHeight
expandedWidth
expandedHeight
topMargin
cornerRadius

animationDuration
springStiffness
springDamping

notificationDuration
mediaDuration
volumeDuration
brightnessDuration
workspaceDuration

showClock
showBattery
showNetwork

enableMedia
enableNotifications
enableVolume
enableBrightness
enableClipboard
enableWorkspace

Use sensible defaults.

================================================== 24. DEVELOPMENT WORKFLOW
========================

Before writing code:

1. Inspect the machine.
2. Inspect existing Quickshell configuration.
3. Inspect Hyprland configuration.
4. Determine available APIs/tools.
5. Create a project structure.
6. Implement the base island.
7. Launch it.
8. Verify that it renders.
9. Add services one at a time.
10. Test every service.
11. Fix errors.
12. Optimize.
13. Polish animations.
14. Make it start automatically with Hyprland.

Do not assume something works merely because the code looks correct.

Actually run Quickshell and inspect errors.

================================================== 25. ERROR HANDLING
==================

If a dependency is missing:

detect it.

If it can safely be installed through pacman:

tell me what you are installing and install it if appropriate.

If installation requires a risky system change, stop and explain.

Do not blindly modify system-critical configuration.

For QML errors:

read the actual error
find the cause
fix the code
restart Quickshell
test again

Continue until the implementation works.

================================================== 26. FINAL RESULT
================

The final result should feel like:

"Someone replaced Waybar with an Apple-inspired Dynamic Island."

Not:

"Someone made a QML rectangle at the top of the screen."

I want:

- premium visual design
- smooth spring animations
- contextual expansion
- beautiful typography
- polished spacing
- responsive interactions
- Hyprland integration
- media integration
- notifications
- volume
- brightness
- workspace awareness
- clipboard integration
- battery/network/clock contextual information
- modular architecture
- centralized theme
- configurable behavior
- low idle resource usage

================================================== 27. IMPORTANT IMPLEMENTATION RULE
=================================

Do not stop after creating the first prototype.

Iterate.

Build → run → inspect → fix → polish → repeat.

If the first version looks crude, improve it.

If an animation feels abrupt, tune it.

If spacing feels wrong, tune it.

If the island looks like a generic widget, redesign it.

The goal is a **high-quality, production-worthy Quickshell desktop interface**, not a tutorial project.

At the end:

1. Tell me exactly what files you created/modified.
2. Tell me how to launch it.
3. Tell me how to autostart it with Hyprland.
4. Tell me what dependencies were required.
5. Tell me what functionality is implemented.
6. Tell me what functionality could not be reproduced and why.
7. Leave the working implementation in my filesystem.

DO NOT merely give me instructions.

BUILD IT.
