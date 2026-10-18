<nav class="fusiondoc-api-breadcrumbs">
	<span>Memory</span>
	<span>Types</span>
	<span>Chore</span>
</nav>

<h1 class="fusiondoc-api-header" markdown>
	<span class="fusiondoc-api-icon" markdown>:octicons-note-24:</span>
	<span class="fusiondoc-api-name">Chore</span>
</h1>

```Lua
export type Chore =
	Instance
	| RBXScriptConnection
	| thread
	| () -> ()
	| {destroy: (self) -> ()}
	| {Destroy: (self) -> ()}
	| {disconnect: (self) -> ()}
	| {Disconnect: (self) -> ()}
	| {Chore}
```
Types which [`doCleanup`](../../members/docleanup) has defined behaviour for.

!!! warning "Not enforced"
	Fusion does not use static types to enforce that `doCleanup` is given a type
	which it can process.

	This type is only exposed for your own use.

-----

## Learn More

- [Scopes tutorial](../../../../tutorials/fundamentals/scopes)
