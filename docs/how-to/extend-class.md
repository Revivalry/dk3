# Add behavior to a class

Use this guide when implementing an actor, weapon, item or map entity in the native
runtime. Class code lives under `src/classes/<kind>/<class>/`.

## Choose the owner

Put behavior used by one class in that class's folder. Put a reusable mechanism in
`src/mechanics`, with parameters supplied by its classes. Game-independent data
structures and algorithms belong in `src/core`.

For example, two projectile classes can share flight/collision handling while each
supplies its own timing, damage and appearance. Do not copy the flight mechanism
into both classes or make it switch on their names.

## Add policy and adapters

1. Put pure state and decisions at the class folder's root.
2. Put engine-facing server/client/domain adapters in the corresponding subfolders.
3. Set line 2 of each module to its role, such as `//! weapon-class: <class>`.
4. Use shared mechanisms through their public contracts. Do not import another class.

Component pointers cannot survive structural changes. Keep persistent IDs when a
later operation needs to resolve an object again.

## Register the class

Add modules to the appropriate data-only registry under `src/game`. Declare the
hooks that the registry dispatches. A weapon uses catalog/weapon hooks; actor
adapters use their actor registry; map entities use classname and system registries.

The existing [class contract](https://github.com/dmytrogajewski/dk3/blob/main/docs/runtime-zig.md#class-contract)
lists hook names and defaults. Follow the existing class family rather than adding
a new dispatch branch to a shared mechanism.

## Check the integrated change

Build the native modules with `zig build game`. Exercise the changed behavior with
the appropriate gameplay scenario, then run the component suite with `zig build test`.
The suite includes the ownership check. If a change removes an existing violation,
lower its baseline with:

```sh
python3 dkq3/tools/class_ownership.py --update
```

Do not raise the baseline to accommodate a new dependency or class-specific branch.

For a behavior port, use the existing
[class review procedure](https://github.com/dmytrogajewski/dk3/blob/main/docs/class-porting.md)
to record the source behavior, animation needs and gameplay cases.
