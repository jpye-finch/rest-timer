# Rest Timer

A small native SwiftUI iOS app for timing rest periods between workout sets.

## Features

- **Two countdown styles** — a full-bleed **Fill** that rises from the bottom past quarter marks, or **Squares** that light in a scattered order until the screen is solid. The choice persists between launches.
- **Grid scaled to the rest** — Squares draws one square per second, so a 30s rest is 30 chunky blocks and a 5:00 rest is 300 small ones. Long custom durations step to coarser units.
- **Tap anywhere** — tap to start the rest, tap again mid-rest to restart from the top. No buttons.
- **Preset durations** — 30s, 60s, 90s, 120s, 150s, 180s, 240s, and 300s, chosen from the countdown's own menu.
- **Custom duration** — a wheel picker (minutes + seconds) for any rest length up to 60 minutes.
- **Flood at zero** — the whole screen turns over to the fill colour the moment the rest is up.
- **Light & dark mode** — built on semantic colours, so it adapts to the system appearance.
- **Background-accurate** — the countdown is anchored to an absolute end date, so it stays correct while the app is backgrounded.
- **Local notification on completion** — a time-sensitive alert fires when the rest is up, even if the app is suspended.
- **Reset from the notification** — the alert carries a **Reset Timer** action so you can restart the next rest without reopening the app.

## Project layout

```
RestTimer.xcodeproj          Xcode project
RestTimer/
  RestTimerApp.swift         App entry point; wires up the shared model + notifications
  ContentView.swift          UI: countdown menu, fill / squares indicators, custom-duration sheet
  RestTimerModel.swift        Countdown state machine (start/pause/reset/add)
  NotificationManager.swift   Permission, scheduling, and interactive notification actions
  Assets.xcassets            App icon + accent color
```

## Building

Open `RestTimer.xcodeproj` in Xcode 15 or later and run on an iOS 16+ simulator
or device. On first launch the app requests notification permission — grant it
so rest-complete alerts (and the Reset action) work.

## How "reset from notification" works

`NotificationManager` registers a `REST_COMPLETE` notification category with a
`Reset Timer` action button. When the completion notification fires and the user
taps that button, `UNUserNotificationCenterDelegate` routes the action to the
shared `RestTimerModel`, which restarts the currently selected duration.
