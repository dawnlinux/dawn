---
id: CMD
aliases: []
tags: []
---

# Java toolkit commands

Every command the Java toolkit defines, and what it puts in the buffer.

- Defined in `lua/engine/tools/java/init.lua`, registered from `lua/engine/tools/init.lua:19`
- **No keymaps are bound to these** — they are `:` commands only. `:Skel` is the one
  shared entry point (see [Skel](#skel-the-shared-entry-point) below)
- The type name always comes from the **file name**, because `javac` requires them to match
- Every command takes a **bang** (`:JavaClass!`) to overwrite a buffer that already has
  content; without it a non-empty buffer is left alone

---

## The commands

| Command           | Generates                                     | Extra arguments                        |
| ----------------- | --------------------------------------------- | -------------------------------------- |
| `:JavaClass`      | `public class`                                | declaration tail (`implements Runnable`) |
| `:JavaInterface`  | `public interface`                            | declaration tail (`permits Circle`)    |
| `:JavaAbstract`   | `public abstract class`                       | declaration tail                       |
| `:JavaFinal`      | `public final class`                          | declaration tail                       |
| `:JavaEnum`       | `public enum`                                 | the constants (`RED, GREEN, BLUE`)     |
| `:JavaRecord`     | `public record`                               | the components (`int x, int y`)        |
| `:JavaAnnotation` | `public @interface` + `@Retention`/`@Target`  | the `@Target` element types (`METHOD, FIELD`) |
| `:JavaException`  | exception class with the two usual constructors | `extends …` clause (default `RuntimeException`) |
| `:JavaMain`       | class with a `main` method                    | declaration tail                       |
| `:JavaTest`       | JUnit 5 test class                            | —                                      |
| `:JavaSingleton`  | eager singleton class                         | —                                      |
| `:Java {kind}`    | dispatcher for all of the above               | see below                              |
| `:JavaPackage`    | inserts or repairs the `package …;` line      | —                                      |

### `:Java` — the dispatcher

`:Java` takes the kind as its first argument and completes it with `<Tab>`:

```vim
:Java rec<Tab>          " -> :Java record
:Java record int x, int y
```

Run it with **no argument** to get a `vim.ui.select` picker listing every kind with
its description.

Kind names for the dispatcher are lowercase: `abstract`, `annotation`, `class`, `enum`,
`exception`, `final`, `interface`, `main`, `record`, `singleton`, `test`.

### `:Skel` — the shared entry point

`:Skel` dispatches on filetype (`lua/engine/tools/init.lua:24`), so the same command
works in a `.java` file, a C++ header, and so on. In a `.java` file it picks the
template from the **file name**:

| File name pattern                     | Template chosen |
| ------------------------------------- | --------------- |
| `FooTest.java`, `FooTests.java`, `TestFoo.java` | `test`    |
| `FooException.java`, `FooError.java`  | `exception`     |
| `Main.java`                           | `main`          |
| anything else                         | `class`         |

### `:JavaPackage`

Reconciles the `package …;` line with where the file actually sits on disk. It will:

- **insert** the declaration when there is none
- **rewrite** it when the file has been moved
- **remove** it (and the blank line after it) when the file moved into the default package
- say `package already correct` and do nothing when it matches

The buffer has to be saved first — the package comes from the file's path.

---

## Examples

```vim
" src/main/java/com/example/app/Point.java
:JavaRecord int x, int y
```

```java
package com.example.app;

public record Point(int x, int y) {
	█
}
```

```vim
" src/main/java/com/example/app/Color.java
:JavaEnum RED, GREEN, BLUE
```

```java
package com.example.app;

public enum Color {
	RED,
	GREEN,
	BLUE;

	█
}
```

```vim
" src/main/java/com/example/app/Loggable.java
:JavaAnnotation METHOD, FIELD
```

```java
package com.example.app;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.METHOD, ElementType.FIELD })
public @interface Loggable {
	█
}
```

```vim
" src/main/java/com/example/app/Task.java
:JavaClass implements Runnable
```

```java
package com.example.app;

public class Task implements Runnable {
	█
}
```

`█` marks where the cursor is parked after the command runs.

---

## How the name and package are worked out

Handled by `lua/engine/tools/java/context.lua`.

**Type name** — from the file name (`Widget.java` → `Widget`). In an unnamed scratch
buffer there is no file name, so the **first argument becomes the name** instead and
everything after it is template input:

```vim
:enew
:JavaClass Scratch implements Runnable
```

If you pass a name that disagrees with the file name you get a warning, because `javac`
will reject a public type there.

**Package** — from the source layout on disk. These roots are recognised, longest first,
and the last occurrence wins so a nested module beats the outer one:

`src/main/java` · `src/test/java` · `src/main/kotlin` · `src/test/kotlin` · `src/java` · `src` · `java`

With no recognisable layout it falls back to the path below the project root, found by
walking up for `pom.xml`, `build.gradle{,.kts}`, `settings.gradle{,.kts}`, or `.git`.

Path segments that are not legal Java identifiers get folded into something that
compiles — `my-app` → `my_app`, `2d` → `_2d`.

**Indentation** matches the buffer: a tab when `noexpandtab`, otherwise `shiftwidth`
(or `tabstop`) spaces.

---

## Messages you may see

| Message                                                    | Meaning                                              |
| ---------------------------------------------------------- | ---------------------------------------------------- |
| `buffer is not empty — re-run with ! to overwrite`         | The guard fired; use `:JavaClass!`                    |
| `no name: save the buffer as Something.java, or pass a name` | Unnamed buffer and no name argument                 |
| `"9bad" is not a valid Java type name`                     | The name is not a legal Java identifier              |
| `unknown kind "…" (try: …)`                                | Bad first argument to `:Java`                        |
| `save the buffer first — the package comes from its path`  | `:JavaPackage` on an unnamed buffer                  |
| `file is in the default package — nothing to declare`      | `:JavaPackage` where no package applies              |

---

## Adding a kind

Add an entry to `M.kinds` in `lua/engine/tools/java/templates.lua`:

```lua
M.kinds.mykind = {
	desc = "shows up in the picker and in :help-style listings",
	build = function(ctx, args, indent)
		local b = builder(indent)
		b:header(ctx)                      -- package line + imports
		b:add(("public class %s {"):format(ctx.type_name))
		b:cursor_line(1)                   -- empty indented line, cursor lands here
		b:add("}")
		return b:result()
	end,
}
```

The command `:JavaMykind` is generated from the key automatically
(`lua/engine/tools/java/init.lua:170`), and the kind joins `:Java`'s completion and
picker with no further wiring. Pass a second argument to `b:header(ctx, { … })` for
imports; an empty string in that list is a deliberate blank line between import groups.
