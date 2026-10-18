<nav class="fusiondoc-api-breadcrumbs">
	<span>Roblox</span>
	<span>Members</span>
	<span>Hydrate</span>
</nav>

<h1 class="fusiondoc-api-header" markdown>
	<span class="fusiondoc-api-icon" markdown>:octicons-workflow-24:</span>
	<span class="fusiondoc-api-name">Hydrate</span>
	<span class="fusiondoc-api-type">
		-> (<a href="../../types/propertytable">PropertyTable</a>) -> Instance
	</span>
</h1>

```Lua
function Fusion.Hydrate(
	scope: Scope<unknown>,
	target: Instance
): (
	props: PropertyTable
) -> Instance
```

Given an instance, returns a component for binding extra functionality to that
instance.

In the property table, string keys are assigned as properties on the instance.
If the value is a [state object](../../../state/types/stateobject), it is
re-assigned every time the value of the state object changes.

Any [special keys](../../types/specialkey) present in the property table are
applied to the instance after string keys are processed, in the order specified
by their `stage`.

A special exception is made for assigning `Parent`, which is only assigned after
the `descendants` stage.

!!! warning "Do not overwrite properties"
	If the instance was previously created with [`New`](../new) or previously
	hydrated, do not assign to any properties that were previously specified in
	those prior calls. Duplicated assignments can interfere with each other in
	unpredictable ways.

-----

## Parameters

<h3 markdown>
	scope
	<span class="fusiondoc-api-type">
		: <a href="../../../memory/types/scope">Scope</a>&lt;unknown&gt;
	</span>
</h3>

The [scope](../../../memory/types/scope) which should be used to store
destruction chores for the instance and its bindings.

!!! note "The target is cleaned up too"
	The target instance is added to the scope, so it will be destroyed when the
	scope is cleaned up.

<h3 markdown>
	target
	<span class="fusiondoc-api-type">
		: Instance
	</span>
</h3>

The instance which should be modified.

-----

<h2 markdown>
	Returns
	<span class="fusiondoc-api-type">
		-> (<a href="../../types/propertytable">PropertyTable</a>) -> Instance
	</span>
</h2>

A component that hydrates that instance, accepting various properties to build
up bindings and operations applied to the instance.

-----

## Learn More

- [Hydration tutorial](../../../../tutorials/roblox/hydration)
